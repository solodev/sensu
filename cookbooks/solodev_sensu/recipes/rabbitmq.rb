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

include_recipe "sensu::rabbitmq"
