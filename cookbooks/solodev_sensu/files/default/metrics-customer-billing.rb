#! /usr/bin/env ruby

require "sensu-plugin/metric/cli"
require "rest-client"
require "json"
require "uri"

class CustomerBillingMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :db,
  description: "InfluxDB database that is queried for metrics",
  short: "-d DATABASE",
  long: "--database DATABASE",
  default: "sensu"

  option :interval,
  description: "The interval this check is reporting customer billing information, e.g. 30m",
  short: "-i INTERVAL",
  long: "--interval 30m",
  default: "30m"

  def influxdb_request(query)
    resource_url = "http://127.0.0.1:8086/query?"
    resource_url << "db=#{config[:db]}"
    resource_url << "&q=#{URI.encode(query)}"
    request = RestClient::Resource.new(resource_url, timeout: 30)
    JSON.parse(request.get, :symbolize_names => true)
  rescue Errno::ECONNREFUSED
    warning "InfluxDB connection refused"
  rescue RestClient::RequestFailed => error
    warning "InfluxDB request failed: #{error}"
  rescue RestClient::RequestTimeout
    warning "InfluxDB connection timed out"
  rescue RestClient::Unauthorized
    warning "Missing or incorrect InfluxDB credentials"
  rescue JSON::ParserError
    warning "InfluxDB returned invalid JSON"
  end

  def send_billing_report(report)
    resource_url = "https://www.solodev.com/_resources/app/php/aws-usage"
    request = RestClient::Resource.new(resource_url, timeout: 30)
    request.post({:payload => JSON.dump(report)})
  rescue Errno::ECONNREFUSED
    warning "Solodev connection refused"
  rescue RestClient::RequestFailed => error
    warning "Solodev request failed: #{error}"
  rescue RestClient::RequestTimeout
    warning "Solodev connection timed out"
  rescue RestClient::Unauthorized
    warning "Missing or incorrect Solodev credentials"
  end

  def get_customer_instance_types_counters
    series = 'customers\..*\.instance_types\..*'
    conditions = "WHERE time > now() - #{config[:interval]}"
    query = "SELECT top(\"value\", 1) FROM /#{series}/ #{conditions}"
    response = influxdb_request(query)
    if response[:results]
      response[:results].first[:series].map do |series|
        value = series[:values].first.last
        path = series[:name].split(".")
        customer_id = path[1]
        instance_type = path.last
        [customer_id, instance_type, value]
      end
    elsif response[:error]
      warning "InfluxDB API returned an error: #{response[:error]}"
    else
      warning "InfluxDB API did not return results"
    end
  end

  def get_customer_network_usage
    network_usage = Hash.new(0)
    series = '.*\.net\.eth0\.(tx|rx)bytes'
    conditions = "WHERE time > now() - #{config[:interval]}"
    query = "SELECT last(value)-first(value) FROM /#{series}/ #{conditions}"
    response = influxdb_request(query)
    if response[:results]
      response[:results].first[:series].map do |series|
        raw_value = series[:values].first.last
        value = (raw_value / 1048576).round
        customer_id = series[:name].split(".").first
        network_usage[customer_id] += value
      end
      network_usage.map do |customer_id, value|
        [customer_id, value]
      end
    elsif response[:error]
      warning "InfluxDB API returned an error: #{response[:error]}"
    else
      warning "InfluxDB API did not return results"
    end
  end

  def get_customer_local_disk_usage
    disk_usage = Hash.new(0)
    series = '.*\.disk\.root\.used$'
    conditions = "WHERE time > now() - #{config[:interval]}"
    query = "SELECT top(\"value\", 1) FROM /#{series}/ #{conditions}"
    response = influxdb_request(query)
    if response[:results]
      response[:results].first[:series].map do |series|
        value = series[:values].first.last
        customer_id = series[:name].split(".").first
        disk_usage[customer_id] += value
      end
      disk_usage.map do |customer_id, value|
        [customer_id, value]
      end
    elsif response[:error]
      warning "InfluxDB API returned an error: #{response[:error]}"
    else
      warning "InfluxDB API did not return results"
    end
  end

  def create_billing_report
    report = {}
    get_customer_instance_types_counters.each do |customer_id, instance_type, value|
      report[customer_id] ||= {}
      report[customer_id][:metrics] ||= {}
      report[customer_id][:metrics][:instance_types] ||= {}
      report[customer_id][:metrics][:instance_types][instance_type] = value
    end
    get_customer_network_usage.each do |customer_id, value|
      report[customer_id] ||= {}
      report[customer_id][:metrics] ||= {}
      report[customer_id][:metrics][:network_usage] ||= {}
      report[customer_id][:metrics][:network_usage] = value
    end
    get_customer_local_disk_usage.each do |customer_id, value|
      report[customer_id] ||= {}
      report[customer_id][:metrics] ||= {}
      report[customer_id][:metrics][:local_disk_usage] ||= {}
      report[customer_id][:metrics][:local_disk_usage] = value
    end
    report
  end

  def run
    timestamp = Time.now.to_i
    report = create_billing_report
    send_billing_report(report)
    report.each do |customer_id, billing_info|
      billing_info[:metrics].each do |metric, value|
        if value.is_a?(Numeric)
          metric_path = ["customers", customer_id, "billing", metric].join(".")
          output(metric_path, value, timestamp)
        else
          value.each do |counter_name, counter_value|
            metric_path = ["customers", customer_id, "billing", metric, counter_name].join(".")
            output(metric_path, counter_value, timestamp)
          end
        end
      end
    end
    ok
  end
end
