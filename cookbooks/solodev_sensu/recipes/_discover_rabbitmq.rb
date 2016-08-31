#
# Cookbook Name:: solodev_sensu
# Recipe:: _discover_rabbitmq
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

# TODO: Stack custom JSON override and conditional HERE.

rabbitmq_nodes = search(:node, "recipes:solodev_sensu\\:\\:rabbitmq")

expanded_recipes = node.run_list.expand(node.chef_environment).recipes

if expanded_recipes.include?("solodev_sensu::rabbitmq")
  rabbitmq_nodes << node
  rabbitmq_nodes.uniq! { |n| n.name }
end

rabbitmq_nodes.sort!

node.run_state["solodev_sensu"] ||= Mash.new
node.run_state["solodev_sensu"]["rabbitmq_nodes"] = rabbitmq_nodes

# TODO: Use appropriate address (public?) for RabbitMQ
node.override["sensu"]["rabbitmq"]["host"] = rabbitmq_nodes.first["hostname"]
