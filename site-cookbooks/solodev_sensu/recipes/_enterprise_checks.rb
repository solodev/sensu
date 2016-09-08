#
# Cookbook Name:: solodev_sensu
# Recipe:: _enterprise_checks
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

sensu_check "disk_usage_local" do
  type "metric"
  command "metrics-disk-usage.rb --local --scheme :::customer_id:::.:::name:::.disk"
  handlers ["influxdb"]
  subscribers ["all"]
  interval 30
end

sensu_check "customer_instance_types_collection" do
  command "echo -n ':::customer_id:::-:::ec2.instance_type:::'"
  aggregate "customer-instance_types"
  handle false
  subscribers ["all"] # TODO: Change this to "customers"
  interval 30
end

cookbook_file "/etc/sensu/plugins/metrics-customer-instance-types.rb" do
  mode "0755"
end

sensu_check "customer_instance_types_metrics" do
  type "metric"
  command "metrics-customer-instance-types.rb"
  handlers ["influxdb"]
  subscribers ["roundrobin:sensu"]
  interval 60
  timeout 30
  additional({
      :ttl => 120
    })
end
