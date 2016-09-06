#
# Cookbook Name:: solodev_sensu
# Recipe:: rabbitmq
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::_discover_rabbitmq"

node.run_state["solodev_sensu"]["rabbitmq_nodes"].each do |rabbitmq_node|
  hostsfile_entry rabbitmq_node["private_ip"] do
    hostname rabbitmq_node["hostname"]
    action :create_if_missing
  end
end

set_sensu_state(node, "ssl", "server", "cacert", citadel["sensu/ssl/ca/ca-cert.pem"])
set_sensu_state(node, "ssl", "server", "cert", citadel["sensu/ssl/server/cert.pem"])
set_sensu_state(node, "ssl", "server", "key", citadel["sensu/ssl/server/key.pem"])

include_recipe "sensu::rabbitmq"
