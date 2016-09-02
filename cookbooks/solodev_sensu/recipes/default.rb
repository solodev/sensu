#
# Cookbook Name:: solodev_sensu
# Recipe:: default
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::_discover_rabbitmq"

set_sensu_state(node, "ssl", "client", "cert", citadel["sensu/ssl/client/cert.pem"])
set_sensu_state(node, "ssl", "client", "key", citadel["sensu/ssl/client/key.pem"])

include_recipe "sensu"
