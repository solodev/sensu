#
# Cookbook Name:: solodev_sensu
# Recipe:: influxdb_config
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

influxdb_database "sensu"

solodev_secrets = JSON.parse(citadel["secrets.json"])

influxdb_username = solodev_secrets["influxdb"]["username"]
influxdb_password = solodev_secrets["influxdb"]["password"]

influxdb_user influxdb_username do
  password influxdb_password
  databases ["sensu"]
end

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
