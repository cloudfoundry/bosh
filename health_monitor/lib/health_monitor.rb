module Bosh
  module HealthMonitor
  end
end

Bhm = Bosh::HealthMonitor

begin
  require "fiber"
rescue LoadError
  unless defined? Fiber
    $stderr.puts "FATAL: HealthMonitor requires Ruby implementation that supports fibers"
    exit 1
  end
end

require "eventmachine"
require "em-http-request"
require "nats/client"
require "logging"
require "yajl"
require "uuidtools"

require "health_monitor/yaml_helper"

require "health_monitor/config"
require "health_monitor/core_ext"
require "health_monitor/version"
require "health_monitor/errors"
require "health_monitor/runner"
require "health_monitor/director"

require "health_monitor/deployment_manager"
require "health_monitor/agent_manager"
