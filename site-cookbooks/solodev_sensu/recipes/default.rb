#
# Cookbook Name:: solodev_sensu
# Recipe:: default
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::_discover_rabbitmq"
include_recipe "sensu"
