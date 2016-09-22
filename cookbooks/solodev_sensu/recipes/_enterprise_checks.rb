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

include_recipe "build-essential"

sensu_gem "rest-client"

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
      :ttl => 240
    })
end

sensu_check "customer_billing_metrics" do
  type "metric"
  command "metrics-customer-billing.rb -i 60m"
  handlers ["influxdb"]
  subscribers ["roundrobin:influxdb"]
  interval 3600
  timeout 30
  additional({
      :ttl => 3800
    })
end

sensu_check "run_duply_backups" do
  command "sudo /usr/bin/duply backup backup"
  subscribers ["SolodevControl", "SolodevProfessional"]
  publish false
end
