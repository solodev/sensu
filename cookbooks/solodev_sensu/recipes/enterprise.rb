#
# Cookbook Name:: solodev_sensu
# Recipe:: enterprise
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

solodev_secrets = JSON.parse(citadel["secrets.json"])

set_sensu_state(node, "enterprise", solodev_secrets["sensu"]["enterprise"])

node.override["sensu"]["redis"]["host"] = node["Elasticache"]["Host"]
node.override["sensu"]["redis"]["port"] = node["Elasticache"]["Port"].to_i

include_recipe "sensu::enterprise"
include_recipe "solodev_sensu::_enterprise_integrations"
include_recipe "solodev_sensu::_enterprise_checks"
include_recipe "sensu::enterprise_service"
include_recipe "solodev_sensu::_enterprise_dashboard"
