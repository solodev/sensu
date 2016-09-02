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
include_recipe "sensu::enterprise_service"

credentials = get_sensu_state(node, "enterprise", "repository", "credentials")
repository_url = "#{node["sensu"]["enterprise"]["repo_protocol"]}://#{credentials['user']}:#{credentials['password']}@#{node["sensu"]["enterprise"]["repo_host"]}"

yum_repository "sensu-enterprise-dashboard" do
  description "sensu enterprise dashboard"
  url "#{repository_url}/yum/x86_64/"
  action :add
  gpgcheck false
end

package "sensu-enterprise-dashboard" do
  version node["sensu"]["enterprise-dashboard"]["version"]
end

node.override["sensu"]["enterprise-dashboard"]["dashboard"]["auth"] = Mash.new

[:public, :private].each do |type|
  path = File.join(node["sensu"]["directory"], "ssl", "dashboard-#{type}.pem")

  file path do
    content citadel["sensu/dashboard/#{type}.pem"]
    owner node["sensu"]["user"]
    group node["sensu"]["group"]
    mode "0600"
  end

  node.override["sensu"]["enterprise-dashboard"]["dashboard"]["auth"]["#{type}key"] = path
end

sensu_dashboard_config node.name

include_recipe "sensu::enterprise_dashboard_service"
