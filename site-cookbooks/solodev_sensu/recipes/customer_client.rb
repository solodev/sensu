#
# Cookbook Name:: solodev_sensu
# Recipe:: customer_client
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

# The following RabbitMQ hosts must be manually updated, as customer
# OpsWorks stacks are unable to discover the active Sensu RabbitMQ
# cluster nodes.
node.override["sensu"]["rabbitmq"]["hosts"] = []

# TODO: Figure out secrets management for customer OpsWorks stacks,
# for the Sensu client SSL certificate/key and credentials.

include_recipe "sensu"

# TODO: Determine the appropriate OpsWorks stack custom JSON
# keyspace for the customer ID.
solodev_custom_json = node["solodev"] || {}
customer_id = solodev_custom_json["customer_id"]

client_subscriptions = ["all", "roundrobin:all"]
if customer_id
  client_subscriptions << "customers"
  client_subscriptions << "customer:#{customer_id}"
end

sensu_client node.name do
  address node["hostname"]
  subscriptions client_subscriptions
  additional({
      "customer_id" => customer_id,
      "ec2" => {
        "instance_id" => node["ec2"]["instance_id"],
        "instance_type" => node["ec2"]["instance_type"]
      }
    })
end

include_recipe "sensu::client_service"
