#
# Cookbook Name:: solodev_sensu
# Recipe:: external_client
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

# The following RabbitMQ hosts must be manually updated, as customer
# OpsWorks stacks are unable to discover the active Sensu RabbitMQ
# cluster nodes.
node.override["sensu"]["rabbitmq"]["hosts"] = [
  "54.167.227.229",
  "107.23.244.171",
  "54.197.2.34"
]

include_recipe "sensu"

sensu_client node.name do
  address node["hostname"]
  subscriptions ["all", "roundrobin:all"]
  additional({
      "ec2" => {
        "instance_id" => node["ec2"]["instance_id"],
        "instance_type" => node["ec2"]["instance_type"]
      }
    })
end

include_recipe "sensu::client_service"
