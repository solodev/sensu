#
# Cookbook Name:: solodev_sensu
# Recipe:: _client_plugins
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

sensu_gem "sensu-plugins-disk-checks" do
  version "2.0.1"
end
