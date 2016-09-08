#
# Cookbook Name:: solodev_sensu
# Recipe:: client
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "solodev_sensu::default"
include_recipe "solodev_sensu::_client_config"
include_recipe "solodev_sensu::_client_extensions"
include_recipe "solodev_sensu::_client_plugins"
include_recipe "sensu::client_service"
