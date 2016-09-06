#
# Cookbook Name:: solodev_sensu
# Recipe:: _discover_influxdb
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

influxdb_layer = Chef::DataBagItem.load("aws_opsworks_layer", "influxdb").to_hash
influxdb_layer_id = influxdb_layer["layer_id"]

opsworks_instances = search("aws_opsworks_instance")

influxdb_nodes = opsworks_instances.select { |instance|
  instance["layer_ids"].include?(influxdb_layer_id)
}.map { |instance| instance.to_hash }

node.run_state["solodev_sensu"] ||= Mash.new
node.run_state["solodev_sensu"]["influxdb_node"] = influxdb_nodes.first
