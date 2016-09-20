SparkleFormation.new(:sensu) do
  set!('AWSTemplateFormatVersion', '2010-09-09')

  parameters(:creator) do
    type 'String'
    description 'Creator of the stack'
  end

  parameters(:vpc_id) do
    type 'String'
  end

  parameters(:subnet_ids) do
    type 'CommaDelimitedList'
  end

  parameters(:redis_instance_type) do
    type 'String'
    default 'cache.m3.medium'
  end

  parameters(:ssh_key_name) do
    type 'String'
    default 'solodev-sensu-shared'
  end

  parameters(:sensu_instance_type) do
    type 'String'
    default 'm3.medium'
  end

  parameters(:rabbitmq_instance_type) do
    type 'String'
    default 'm3.medium'
  end

  parameters(:influxdb_instance_type) do
    type 'String'
    default 'm3.medium'
  end

  parameters(:bucket_name) do
    type 'String'
    default 'solodev-sensu-opsworks'
  end

  parameters(:artifact_path) do
    type 'String'
  end

  dynamic!(:ec2_security_group, :redis, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_name!, " Redis shared security group")
      vpc_id ref!(:vpc_id)
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
      automatic_failover_enabled 'true'
      auto_minor_version_upgrade 'false'
      num_cache_clusters 2
      cache_node_type ref!(:redis_instance_type)
      cache_parameter_group_name ref!(:redis_parameter_group)
      cache_subnet_group_name ref!(:redis_subnet_group)
      security_group_ids [attr!(:redis_security_group, :group_id)]
      port '6379'
      engine 'redis'
      engine_version '2.8.24'
    end
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

  dynamic!(:ec2_security_group, :sensu_elb, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_id!, " Sensu ELB security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
          from_port '80'
          to_port '80'
          ip_protocol 'tcp'
        }
      )
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

  dynamic!(:ec2_security_group_ingress, :sensu_dashboard, :resource_name_suffix => :ingress_rule) do
    properties do
      group_id attr!(:sensu_security_group, :group_id)
      source_security_group_id attr!(:sensu_elb_security_group, :group_id)
      ip_protocol 'tcp'
      from_port 3000
      to_port 3000
    end
  end

  dynamic!(:ec2_security_group_ingress, :redis_sensu, :resource_name_suffix => :ingress_rule) do
    properties do
      group_id ref!(:redis_security_group)
      source_security_group_id attr!(:sensu_security_group, :group_id)
      ip_protocol 'tcp'
      from_port 6379
      to_port 6379
    end
  end

  dynamic!(:ec2_security_group, :rabbitmq, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_id!, " RabbitMQ shared security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
          from_port '5671'
          to_port '5671'
          ip_protocol 'tcp'
        }
      )
    end
  end

  { :epmd => [ 4369 ], :node => [ 25671, 25672 ] }.each_pair do |name, port_range|
    dynamic!(:ec2_security_group_ingress, "rabbitmq_#{name}".to_sym, :resource_name_suffix => :ingress_rule) do
      properties do
        group_id attr!(:rabbitmq_security_group, :group_id)
        source_security_group_id attr!(:rabbitmq_security_group, :group_id)
        ip_protocol 'tcp'
        from_port port_range.first
        to_port port_range.last
      end
    end
  end

  dynamic!(:ec2_security_group, :influxdb, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_id!, " InfluxDB security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
          from_port '80'
          to_port '80'
          ip_protocol 'tcp'
        }
      )
    end
  end

  dynamic!(:ec2_security_group_ingress, :influxdb_sensu, :resource_name_suffix => :ingress_rule) do
    properties do
      group_id attr!(:influxdb_security_group, :group_id)
      source_security_group_id attr!(:sensu_security_group, :group_id)
      ip_protocol 'tcp'
      from_port 8080
      to_port 8090
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

  resources(:sensu_stack) do
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
      custom_json do
        elasticache do
          host attr!(:redis_replication_group, 'PrimaryEndPoint.Address')
          port attr!(:redis_replication_group, 'PrimaryEndPoint.Port')
        end
      end
      configuration_manager do
        name 'Chef'
        version '12'
      end
      default_subnet_id select!(0, ref!(:subnet_ids))
      vpc_id ref!(:vpc_id)
    end
  end

  resources(:rabbitmq_leader_layer) do
    type 'AWS::OpsWorks::Layer'
    properties do
      name "rabbitmq-leader"
      shortname "rabbitmq-leader"
      stack_id ref!(:sensu_stack)
      type 'custom'
      enable_auto_healing 'true'
      auto_assign_elastic_ips 'true'
      auto_assign_public_ips 'true'
      custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      custom_security_group_ids [ref!(:sensu_security_group), ref!(:rabbitmq_security_group)]
      custom_recipes do
        setup [ "solodev_sensu::rabbitmq" ]
        configure [ "solodev_sensu::rabbitmq_leader", "solodev_sensu::client" ]
        deploy []
        undeploy []
        shutdown []
      end
    end
  end

  %w[ one two ].each do |i|
    resources("rabbitmq_follower_#{i}_layer".to_sym) do
      type 'AWS::OpsWorks::Layer'
      properties do
        name "rabbitmq-follower-#{i}"
        shortname "rabbitmq-follower-#{i}"
        stack_id ref!(:sensu_stack)
        type 'custom'
        enable_auto_healing 'true'
        auto_assign_elastic_ips 'true'
        auto_assign_public_ips 'true'
        custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
        custom_security_group_ids [ref!(:sensu_security_group), ref!(:rabbitmq_security_group)]
        custom_recipes do
          setup [ "solodev_sensu::rabbitmq" ]
          configure [ "solodev_sensu::rabbitmq_follower", "solodev_sensu::client" ]
          deploy []
          undeploy []
          shutdown []
        end
      end
    end
  end

  resources(:sensu_layer) do
    type 'AWS::OpsWorks::Layer'
    properties do
      name 'sensu'
      shortname 'sensu'
      stack_id ref!(:sensu_stack)
      type 'custom'
      enable_auto_healing 'true'
      auto_assign_elastic_ips 'true'
      auto_assign_public_ips 'true'
      custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      custom_security_group_ids [ref!(:sensu_security_group)]
      custom_recipes do
        setup [ "solodev_sensu::client", "solodev_sensu::enterprise" ]
        configure [ "solodev_sensu::client", "solodev_sensu::enterprise" ]
        deploy []
        undeploy []
        shutdown []
      end
    end
  end

  resources(:sensu_layer_elb) do
    type 'AWS::ElasticLoadBalancing::LoadBalancer'
    properties do
      security_groups [ref!(:sensu_elb_security_group)]
      subnets ref!(:subnet_ids)
      health_check do
        healthy_threshold 5
        interval 10
        target 'http:3000/'
        unhealthy_threshold 3
        timeout 5
      end
      listeners array!(
        -> {
          instance_port '3000'
          load_balancer_port '80'
          protocol 'http'
        }
      )
    end
  end

  resources(:sensu_layer_elb_attachment) do
    type 'AWS::OpsWorks::ElasticLoadBalancerAttachment'
    properties do
      elastic_load_balancer_name ref!(:sensu_layer_elb)
      layer_id ref!(:sensu_layer)
    end
  end

  resources(:influxdb_layer) do
    type 'AWS::OpsWorks::Layer'
    properties do
      name 'influxdb'
      shortname 'influxdb'
      stack_id ref!(:sensu_stack)
      type 'custom'
      enable_auto_healing 'true'
      auto_assign_elastic_ips 'true'
      auto_assign_public_ips 'true'
      custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      custom_security_group_ids [ref!(:influxdb_security_group)]
      custom_recipes do
        setup [ "solodev_sensu::client", "solodev_sensu::influxdb" ]
        configure [ "solodev_sensu::client", "solodev_sensu::influxdb", "solodev_sensu::influxdb_config" ]
        deploy []
        undeploy []
        shutdown []
      end
    end
  end

  %w[ leader follower_one follower_two ].each_with_index do |broker, count|
    rabbit_layer = "rabbitmq_#{broker}_layer".to_sym
    resources("rabbitmq_#{broker}_instance".to_sym) do
      type 'AWS::OpsWorks::Instance'
      properties do
        instance_type ref!(:rabbitmq_instance_type)
        layer_ids [ref!(rabbit_layer)]
        os 'CentOS Linux 7'
        root_device_type 'ebs'
        ssh_key_name ref!(:ssh_key_name)
        stack_id ref!(:sensu_stack)
        subnet_id select!(count, ref!(:subnet_ids))
      end
    end
  end

  %w[ follower_one follower_two ].each do |broker|
    resources("rabbitmq_#{broker}_instance".to_sym) do
      depends_on process_key!(:rabbitmq_leader_instance)
    end
  end

  resources(:influxdb_instance) do
    type 'AWS::OpsWorks::Instance'
    properties do
      instance_type ref!(:influxdb_instance_type)
      layer_ids [ref!(:influxdb_layer)]
      os 'CentOS Linux 7'
      root_device_type 'ebs'
      ssh_key_name ref!(:ssh_key_name)
      stack_id ref!(:sensu_stack)
      subnet_id select!(1, ref!(:subnet_ids))
    end
    depends_on process_key!(:rabbitmq_leader_instance)
  end

  [1, 2].each do |i|
    resources("sensu_instance_#{i}".to_sym) do
      type 'AWS::OpsWorks::Instance'
      properties do
        instance_type ref!(:sensu_instance_type)
        layer_ids [ref!(:sensu_layer)]
        os 'Amazon Linux 2016.03'
        root_device_type 'ebs'
        ssh_key_name ref!(:ssh_key_name)
        stack_id ref!(:sensu_stack)
        subnet_id select!(i, ref!(:subnet_ids))
      end
      depends_on process_key!(:influxdb_instance)
    end
  end

  outputs do
    redis_security_group_id do
      value attr!(:redis_security_group, :group_id)
    end

    redis_primary_endpoint_address do
      value attr!(:redis_replication_group, 'PrimaryEndPoint.Address')
    end

    redis_primary_endpoint_port do
      value attr!(:redis_replication_group, 'PrimaryEndPoint.Port')
    end

    sensu_dashboard_url do
      value join!('http://', attr!(:sensu_layer_elb, 'DNSName'))
    end
  end
end
