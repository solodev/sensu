#
# Cookbook Name:: solodev_sensu
# Recipe:: client
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::default"

sensu_client node.name do
  address node["hostname"]
  subscriptions ["all", "roundrobin:all"]
  additional({
    "instance_type" => "",
    "customer_id" => ""
  })
end

include_recipe "sensu::client_service"
