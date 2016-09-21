#
# Cookbook Name:: solodev_sensu
# Recipe:: backup_check
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "sudo"

sudo "sensu_duply" do
  user "sensu"
  runas "root"
  nopasswd true
  commands ["/usr/bin/duply backup backup"]
end

cookbook_file "/usr/bin/duply_backups.sh" do
  mode "0755"
end
