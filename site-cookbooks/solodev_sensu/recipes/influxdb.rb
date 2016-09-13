#
# Cookbook Name:: solodev_sensu
# Recipe:: influxdb
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "influxdb"

influxdb_database "sensu"

solodev_secrets = JSON.parse(citadel["secrets.json"])

influxdb_username = solodev_secrets["influxdb"]["username"]
influxdb_password = solodev_secrets["influxdb"]["password"]

influxdb_user influxdb_username do
  password influxdb_password
  databases ["sensu"]
end

include_recipe "grafana"

grafana_datasource "influxdb" do
  source({
      :type => "influxdb_09",
      :url => "http://127.0.0.1:8086",
      :access => "proxy",
      :database => "sensu",
      :user => influxdb_username,
      :password => influxdb_password,
      :isdefault => true
    })
  action :create
end

include_recipe "build-essential"

sensu_gem "rest-client"

cookbook_file "/etc/sensu/plugins/metrics-customer-billing.rb" do
  mode "0755"
end
