SparkleFormation.new(:sensu).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')

  parameters(:stack_creator) do
    type 'String'
    default ENV['USER']
  end

  parameters(:ssh_key_name) do
    type 'String'
    default 'solodev-sensu-shared'
  end

  parameters(:sensu_instance_type) do
    type 'String'
    default 't2.micro'
  end

  parameters(:rabbitmq_instance_type) do
    type 'String'
    default 'm1.small'
  end

  parameters(:redis_instance_type) do
    type 'String'
    default 'cache.t2.micro'
  end

  parameters(:vpc_id) do
    type 'String'
    description 'VPC to Join'
  end

  parameters(:subnet_ids) do
    type 'CommaDelimitedList'
  end

  parameters(:bucket_name) do
    type 'String'
    default 'solodev-sensu-opsworks'
  end

  parameters(:artifact_path) do
    type 'String'
  end

  resources(:sensu_iam_role) do
    type 'AWS::IAM::Role'
    properties do
      path '/'
      assume_role_policy_document.statement array!(
        -> {
          effect 'Allow'
          principal.service ['ec2.amazonaws.com']
          action 'sts:AssumeRole'
        }
      )
      policies array!(
        -> {
          policy_name 'PowerUserPolicy'
          policy_document do
            statement array!(
              -> {
                sid 'PowerUserStmt'
                effect 'Allow'
                not_action 'iam:*'
                resource '*'
              }
            )
          end
        }
      )
    end
  end

  resources(:opsworks_service_iam_role) do
    type 'AWS::IAM::Role'
    properties do
      path '/'
      assume_role_policy_document do
        statement  array!(
          -> {
            effect 'Allow'
            principal.service ['opsworks.amazonaws.com']
            action 'sts:AssumeRole'
          }
        )
      end
      policies array!(
        -> {
          policy_name 'OpsWorksService'
          policy_document do
            statement array!(
              -> {
                effect 'Allow'
                action [
                  'rds:*',
                  'ec2:*',
                  'iam:PassRole',
                  'cloudwatch:GetMetricStatistics',
                  'elasticloadbalancing:*'
                ]
                resource '*'
              }
            )
          end
        }
      )
    end
  end

  dynamic!(:iam_instance_profile, :sensu) do
    properties do
      path '/'
      roles [ref!(:sensu_iam_role)]
    end
  end

  dynamic!(:ec2_security_group, :sensu, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_id!, " Sensu shared security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
          from_port '22'
          to_port '22'
          ip_protocol 'tcp'
        }
      )
    end
  end

  dynamic!(:ec2_security_group, :redis, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_name!, " Redis shared security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          source_security_group_id ref!(:sensu_security_group)
          from_port '6379'
          to_port '6379'
          ip_protocol 'tcp'
        }
      )
    end
  end

  resources(:redis_parameter_group) do
    type 'AWS::ElastiCache::ParameterGroup'
    properties do
      description join!(
        'redis-2.8 parameters for ', stack_name!
      )
      cache_parameter_group_family 'redis2.8'
      # see http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/CacheParameterGroups.Redis.html
      # for supported properties
      # Redis example:
      properties do
        _camel_keys_set(:auto_disable)
        set!('slowlog-max-len', 256)
      end
    end
  end

  resources(:redis_subnet_group) do
    type 'AWS::ElastiCache::SubnetGroup'
    properties do
      description join!(
        stack_name!, " redis 2.8.24"
      )
      subnet_ids ref!(:subnet_ids)
    end
  end

  resources(:redis_replication_group) do
    type 'AWS::ElastiCache::ReplicationGroup'
    properties do
      replication_group_description join!(stack_name!, ' Redis 2.8.24')
      automatic_failover_enabled 'false'
      auto_minor_version_upgrade 'false'
      num_cache_clusters 1
      cache_node_type ref!(:redis_instance_type)
      cache_parameter_group_name ref!(:redis_parameter_group)
      cache_subnet_group_name ref!(:redis_subnet_group)
      security_group_ids [ref!(:redis_security_group)]
      port '6379'
      engine 'redis'
      engine_version '2.8.24'
    end
  end

  resources(:sensu_iam_user) do
    type 'AWS::IAM::User'
    properties do
      policies array!(
        ->{
          policy_name 'allow_s3_cookbook_access'
          policy_document do
            statement array!(
              -> {
                effect 'Allow'
                action [ 's3:GetObject' ]
                resource [
                  join!('arn:aws:s3:::', ref!(:bucket_name)),
                  join!('arn:aws:s3:::', ref!(:bucket_name), '/*')
                ]
              }
            )
          end
        }
      )
    end
  end

  resources(:sensu_iam_access_key) do
    type 'AWS::IAM::AccessKey'
    properties do
      user_name ref!(:sensu_iam_user)
    end
  end

  resources(:sensu_rabbitmq_stack) do
    type 'AWS::OpsWorks::Stack'
    properties do
      name stack_name!
      service_role_arn attr!(:opsworks_service_iam_role, :arn)
      default_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      use_custom_cookbooks 'true'
      custom_cookbooks_source do
        type 's3'
        username ref!(:sensu_iam_access_key)
        password attr!(:sensu_iam_access_key, :secret_access_key)
        url join!('https://', ref!(:bucket_name), '.s3.amazonaws.com/', ref!(:artifact_path))
      end
      configuration_manager do
        name 'Chef'
        version '12'
      end
      default_subnet_id select!(0, ref!(:subnet_ids))
      vpc_id ref!(:vpc_id)
    end
  end

  resources(:sensu_rabbitmq_instance) do
    type 'AWS::OpsWorks::Instance'
    properties do
      instance_type ref!(:rabbitmq_instance_type)
      layer_ids [ref!(:sensu_rabbitmq_layer)]
      os 'CentOS Linux 7'
      root_device_type 'ebs'
      ssh_key_name ref!(:ssh_key_name)
      stack_id ref!(:sensu_rabbitmq_stack)
      subnet_id select!(0, ref!(:subnet_ids))
    end
  end

  resources(:sensu_rabbitmq_layer) do
    type 'AWS::OpsWorks::Layer'
    properties do
      name 'sensu-rabbitmq'
      shortname 'sensu-rabbitmq'
      stack_id ref!(:sensu_rabbitmq_stack)
      type 'custom'
      enable_auto_healing 'false'
      auto_assign_elastic_ips 'true'
      auto_assign_public_ips 'true'
      custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      custom_security_group_ids [ref!(:sensu_security_group)]
      custom_recipes do
        setup [ "solodev_sensu::rabbitmq" ]
        configure []
        deploy []
        undeploy []
        shutdown []
      end
    end
  end

  resources(:sensu_rabbitmq_app) do
    type 'AWS::OpsWorks::App'
    properties do
      stack_id ref!(:sensu_rabbitmq_stack)
      name 'sensu-rabbitmq'
      type 'other'
    end
  end

  outputs do
    redis_security_group_id do
      value attr!(:redis_security_group, 'GroupId')
    end

    redis_primary_endpoint_address do
      value attr!(:redis_replication_group, 'PrimaryEndPoint.Address')
    end

    redis_primary_endpoint_port do
      value attr!(:redis_replication_group, 'PrimaryEndPoint.Port')
    end
  end

end
