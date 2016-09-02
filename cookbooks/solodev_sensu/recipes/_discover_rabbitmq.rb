#
# Cookbook Name:: solodev_sensu
# Recipe:: _discover_rabbitmq
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

leader_layer = Chef::DataBagItem.load("aws_opsworks_layer", "rabbitmq-leader").to_hash
leader_layer_id = leader_layer["layer_id"]

follower_layer = Chef::DataBagItem.load("aws_opsworks_layer", "rabbitmq-follower").to_hash
follower_layer_id = follower_layer["layer_id"]

opsworks_instances = search("aws_opsworks_instance")

rabbitmq_nodes = opsworks_instances.select { |instance|
  instance["layer_ids"].include?(leader_layer_id) ||
  instance["layer_ids"].include?(follower_layer_id)
}.map { |instance| instance.to_hash }

rabbitmq_leader_nodes = opsworks_instances.select { |instance|
  instance["layer_ids"].include?(leader_layer_id)
}.map { |instance| instance.to_hash }

leader_node = rabbitmq_leader_nodes.first

node.run_state["solodev_sensu"] ||= Mash.new
node.run_state["solodev_sensu"]["rabbitmq_nodes"] = rabbitmq_nodes
node.run_state["solodev_sensu"]["rabbitmq_cluster_nodes"] = [
  {
    "name" => "rabbit@#{leader_node["hostname"]}",
    "type" => "disc"
  }
]

node.override["sensu"]["rabbitmq"]["host"] = leader_node["public_dns"]
