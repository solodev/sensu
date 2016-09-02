#
# Cookbook Name:: solodev_sensu
# Recipe:: rabbitmq_leader
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::rabbitmq"

cluster_nodes = node.run_state["solodev_sensu"]["rabbitmq_cluster_nodes"].to_json

rabbitmq_cluster cluster_nodes do
  cluster_name "sensu"
  action :set_cluster_name
end

rabbitmq_policy "ha-sensu" do
  pattern "^(results$|keepalives$)"
  params("ha-mode" => "all", "ha-sync-mode" => "automatic")
  vhost node["sensu"]["rabbitmq"]["vhost"]
  action :set
end
