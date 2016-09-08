#! /usr/bin/env ruby

require "sensu-plugin/metric/cli"
require "socket"
require "rest-client"
require "json"

class CustomerInstanceTypesMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
  description: "Metric naming scheme, text to prepend to .$parent.$child",
  long: "--scheme SCHEME",
  default: "#{Socket.gethostname}.instance_types"

  def api_request(resource)
    resource_url = "http://127.0.0.1:4567#{resource}"
    request = RestClient::Resource.new(resource_url, timeout: 30)
    JSON.parse(request.get, :symbolize_names => true)
  rescue Errno::ECONNREFUSED
    warning "Connection refused"
  rescue RestClient::RequestFailed
    warning "Request failed"
  rescue RestClient::RequestTimeout
    warning "Connection timed out"
  rescue RestClient::Unauthorized
    warning "Missing or incorrect Sensu API credentials"
  rescue JSON::ParserError
    warning "Sensu API returned invalid JSON"
  end

  def get_instance_types_counters
    response = api_request("/aggregates/customer-instance_types/results/ok")
    types_collection = response.detect do |value|
      value[:check] == "customer_instance_types_collection"
    end
    timestamp = Time.now.to_i
    types_collection[:summary].each do |summary|
      parts = summary[:output].rpartition("-")
      metric_path = [config[:scheme], parts.first, parts.last.sub(".", "_")].join(".")
      output(metric_path, summary[:total], timestamp)
    end
  end

  def run
    get_instance_types_counters
    ok
  end
end
