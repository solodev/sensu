#
# Cookbook Name:: solodev_sensu
# Recipe:: _client_config
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

opsworks_instances = search("aws_opsworks_instance")

client_instance = opsworks_instances.select { |instance|
  instance["hostname"] == node["hostname"]
}.first.to_hash

opsworks_layers = search("aws_opsworks_layer")

client_layers = opsworks_layers.select { |layer|
  client_instance["layer_ids"].include?(layer["layer_id"])
}.map { |layer| layer.to_hash }

layer_subscriptions = client_layers.map { |layer|
  [layer["name"], "roundrobin:#{layer["name"]}"]
}.flatten

client_subscriptions = ["all", "roundrobin:all"]
client_subscriptions += layer_subscriptions

# TODO: Determine the appropriate OpsWorks stack custom JSON
# keyspace for the customer ID.
solodev_custom_json = node["solodev"] || {}
customer_id = solodev_custom_json["customer_id"] || "solodev-sensu"

client_subscriptions << "customer:#{customer_id}"

client_name = [node["hostname"], node["ec2"]["instance_id"]].join("-")

sensu_client client_name do
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
