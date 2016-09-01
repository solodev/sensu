SparkleFormation.new(:sensu).load(:base).overrides do

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

  parameters(:bucket_name) do
    type 'String'
    default 'solodev-sensu-opsworks'
  end

  parameters(:artifact_path) do
    type 'String'
  end

  %w(
    security_group_id
    primary_endpoint_address
    primary_endpoint_port
  ).each do |param|
    parameters("redis_#{param}".to_sym) do
      type 'String'
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
      configuration_manager do
        name 'Chef'
        version '12'
      end
      default_subnet_id select!(0, ref!(:subnet_ids))
      vpc_id ref!(:vpc_id)
    end
  end

  %w( leader follower ).each do |type|
    resources("rabbitmq_#{type}_layer".to_sym) do
      type 'AWS::OpsWorks::Layer'
      properties do
        name "rabbitmq-#{type}"
        shortname "rabbitmq-#{type}"
        stack_id ref!(:sensu_stack)
        type 'custom'
        enable_auto_healing 'false'
        auto_assign_elastic_ips 'true'
        auto_assign_public_ips 'true'
        custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
        custom_security_group_ids [ref!(:sensu_security_group), ref!(:rabbitmq_security_group)]
        custom_recipes do
          setup [ "solodev_sensu::rabbitmq" ]
          configure []
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
      enable_auto_healing 'false'
      auto_assign_elastic_ips 'true'
      auto_assign_public_ips 'true'
      custom_instance_profile_arn attr!(:sensu_iam_instance_profile, :arn)
      custom_security_group_ids [ref!(:sensu_security_group)]
      custom_recipes do
        setup []
        configure []
        deploy []
        undeploy []
        shutdown []
      end
    end
  end

  rabbit_count = 0
  %w( leader follower1 follower2 ).each do |type|
    rabbit_layer = "rabbitmq_#{type.gsub(/[0-9]/,"")}_layer".to_sym
    resources("rabbitmq_#{type}_instance".to_sym) do
      type 'AWS::OpsWorks::Instance'
      properties do
        instance_type ref!(:rabbitmq_instance_type)
        layer_ids [ref!(rabbit_layer)]
        os 'CentOS Linux 7'
        root_device_type 'ebs'
        ssh_key_name ref!(:ssh_key_name)
        stack_id ref!(:sensu_stack)
        subnet_id select!(rabbit_count, ref!(:subnet_ids))
      end
    end
    rabbit_count += 1
  end

  [1, 2].each do |i|
    resources("rabbitmq_follower#{i}_instance".to_sym) do
      depends_on process_key!(:rabbitmq_leader_instance)
    end
  end

  1.times do |i|
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
      depends_on process_key!(:rabbitmq_leader_instance)
    end
  end
end
