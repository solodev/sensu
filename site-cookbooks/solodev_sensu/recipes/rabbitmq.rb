#
# Cookbook Name:: solodev_sensu
# Recipe:: rabbitmq
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "sensu::rabbitmq"

rabbitmq_policy "ha-sensu" do
  pattern "^(results$|keepalives$)"
  params("ha-mode" => "all", "ha-sync-mode" => "automatic")
  vhost node["sensu"]["rabbitmq"]["vhost"]
  action :set
end
