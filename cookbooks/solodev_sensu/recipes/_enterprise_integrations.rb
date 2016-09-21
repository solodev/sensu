#
# Cookbook Name:: solodev_sensu
# Recipe:: _enterprise_integrations
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

solodev_secrets = JSON.parse(citadel["secrets.json"])

include_recipe "solodev_sensu::_discover_influxdb"

influxdb_host = node.run_state["solodev_sensu"]["influxdb_node"]["private_ip"]
influxdb_username = solodev_secrets["influxdb"]["username"]
influxdb_password = solodev_secrets["influxdb"]["password"]

sensu_snippet "influxdb" do
  content({
      :host => influxdb_host,
      :port => 8086,
      :username => influxdb_username,
      :password => influxdb_password,
      :api_version => "0.9",
      :database => "sensu"
    })
end

hipchat_api_token = solodev_secrets["hipchat"]["api_token"]
hipchat_username = solodev_secrets["hipchat"]["username"]
hipchat_room = solodev_secrets["hipchat"]["room"]

sensu_snippet "hipchat" do
  content({
      :api_token => hipchat_api_token,
      :username => hipchat_username,
      :room => hipchat_room
    })
end

sensu_handler "default" do
  type "set"
  handlers ["hipchat"]
end
