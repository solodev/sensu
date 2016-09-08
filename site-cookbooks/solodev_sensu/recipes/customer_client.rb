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
# for the Sensu client SSL certificate/key. Currently using citadel
# with the Sensu OpsWorks stack S3 bucket.
set_sensu_state(node, "ssl", "client", "cert", citadel["sensu/ssl/client/cert.pem"])
set_sensu_state(node, "ssl", "client", "key", citadel["sensu/ssl/client/key.pem"])

include_recipe "sensu"
include_recipe "solodev_sensu::_client_config"
include_recipe "solodev_sensu::_client_extensions"
include_recipe "solodev_sensu::_client_plugins"
include_recipe "sensu::client_service"
