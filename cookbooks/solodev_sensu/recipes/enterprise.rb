#
# Cookbook Name:: solodev_sensu
# Recipe:: enterprise
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

solodev_secrets = JSON.parse(citadel["secrets.json"])

set_sensu_state(node, "enterprise", solodev_secrets["sensu"]["enterprise"])

include_recipe "sensu::enterprise"
