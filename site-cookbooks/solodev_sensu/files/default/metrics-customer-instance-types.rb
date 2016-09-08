#! /usr/bin/env ruby

require "sensu-plugin/metric/cli"
require "socket"

class CustomerInstanceTypesMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
  description: "Metric naming scheme, text to prepend to .$parent.$child",
  long: "--scheme SCHEME",
  default: "#{Socket.gethostname}.instance_types"

  def run
    output([config[:scheme], "m3_medium"].join("."), 42, nil)
    ok
  end
end
