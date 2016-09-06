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
