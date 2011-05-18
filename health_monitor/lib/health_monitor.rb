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

# Managers
require "health_monitor/deployment_manager"
require "health_monitor/agent_manager"

# Alert processing
require "health_monitor/alert_processor"
require "health_monitor/alert_processors/base"
require "health_monitor/alert_processors/silent"
require "health_monitor/alert_processors/email"
