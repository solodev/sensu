#
# Cookbook Name:: solodev_sensu
# Recipe:: backup_check
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

include_recipe "sudo"

backup_command = "/usr/bin/duply backup backup"

sudo "sensu_duply" do
  user "sensu"
  runas "root"
  nopasswd true
  commands [backup_command]
end

sensu_check "run_duply_backups" do
  command "sudo #{backup_command}"
  standalone true
  interval 86400 # Run every 24 hours
  additional({
      :ttl => 129600 # Expect a result every 36 hours
    })
end
