SparkleFormation.new(:elasticache).load(:base).overrides do
  parameters(:redis_instance_type) do
    type 'String'
    default 'cache.t2.micro'
  end

  dynamic!(:ec2_security_group, :redis, :resource_name_suffix => :security_group) do
    properties do
      group_description join!(stack_name!, " Redis shared security group")
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
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
