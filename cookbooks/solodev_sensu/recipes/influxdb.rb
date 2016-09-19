#
# Cookbook Name:: solodev_sensu
# Recipe:: influxdb
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "influxdb"
include_recipe "grafana"

include_recipe "build-essential"

sensu_gem "rest-client"

cookbook_file "/etc/sensu/plugins/metrics-customer-billing.rb" do
  mode "0755"
end
