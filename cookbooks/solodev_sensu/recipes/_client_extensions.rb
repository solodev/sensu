#
# Cookbook Name:: solodev_sensu
# Recipe:: _client_extensions
#
# Copyright (c) 2016 Solodev, All Rights Reserved.

sensu_gem "sensu-extensions-system-profile" do
  version "1.0.0"
end

sensu_snippet "extensions" do
  content({
      "system-profile" => {
        :version => "1.0.0"
      }
    })
end

# TODO: Determine the appropriate OpsWorks stack custom JSON
# keyspace for the customer ID.
solodev_custom_json = node["solodev"] || {}
customer_id = solodev_custom_json["customer_id"] || "solodev-sensu"

client_name = [node["hostname"], node["ec2"]["instance_id"]].join("-")

sensu_snippet "system_profile" do
  content({
      :add_client_prefix => false,
      :path_prefix => "#{customer_id}.#{client_name}",
      :handler => "influxdb"
    })
end
