#
# Cookbook Name:: solodev_sensu
# Recipe:: rabbitmq_follower
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::rabbitmq"

execute "reset_rabbitmq_app" do
  command "/sbin/rabbitmqctl reset"
  action :nothing
end

execute "stop_rabbitmq_app" do
  command "/sbin/rabbitmqctl stop_app"
  not_if "/sbin/rabbitmqctl cluster_status | grep cluster_name | grep sensu"
  action :run
  notifies :run, "execute[reset_rabbitmq_app]", :immediately
end

cluster_nodes = node.run_state["solodev_sensu"]["rabbitmq_cluster_nodes"].to_json

rabbitmq_cluster cluster_nodes do
  cluster_name "sensu"
  action :join
end
