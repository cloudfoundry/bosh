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

# Deps
require "eventmachine"
require "em-http-request"
require "nats/client"
require "logging"
require "yajl"
require "uuidtools"

require "set"

# Helpers
require "health_monitor/yaml_helper"

# Basic blocks
require "health_monitor/config"
require "health_monitor/core_ext"
require "health_monitor/version"
require "health_monitor/errors"
require "health_monitor/runner"
require "health_monitor/director"
require "health_monitor/agent"
require "health_monitor/alert"

# Managers
require "health_monitor/agent_manager"

# Alert processing
require "health_monitor/alert_processor"

# Alert delivery
require "health_monitor/delivery_agents/base"
require "health_monitor/delivery_agents/logging"
require "health_monitor/delivery_agents/email"
require "health_monitor/delivery_agents/pagerduty"
