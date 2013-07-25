module Bosh
  module HealthMonitor
  end
end

Bhm = Bosh::HealthMonitor

begin
  require 'fiber'
rescue LoadError
  unless defined? Fiber
    $stderr.puts 'FATAL: HealthMonitor requires Ruby implementation that supports fibers'
    exit 1
  end
end

require 'ostruct'
require 'set'

require 'em-http-request'
require 'eventmachine'
require 'logging'
require 'nats/client'
require 'sinatra'
require 'thin'
require 'securerandom'
require 'yajl'

# Helpers
require 'health_monitor/yaml_helper'

# Basic blocks
require 'health_monitor/agent'
require 'health_monitor/config'
require 'health_monitor/core_ext'
require 'health_monitor/director'
require 'health_monitor/director_monitor'
require 'health_monitor/errors'
require 'health_monitor/metric'
require 'health_monitor/runner'
require 'health_monitor/version'

# Processing
require 'health_monitor/agent_manager'
require 'health_monitor/event_processor'

# HTTP endpoints
require 'health_monitor/api_controller'

# Protocols
require 'health_monitor/protocols/tsdb'

# Events
require 'health_monitor/events/base'
require 'health_monitor/events/alert'
require 'health_monitor/events/heartbeat'

# Plugins
require 'health_monitor/plugins/base'
require 'health_monitor/plugins/dummy'
require 'health_monitor/plugins/http_request_helper'
require 'health_monitor/plugins/resurrector_helper'
require 'health_monitor/plugins/cloud_watch'
require 'health_monitor/plugins/datadog'
require 'health_monitor/plugins/paging_datadog_client'
require 'health_monitor/plugins/email'
require 'health_monitor/plugins/logger'
require 'health_monitor/plugins/nats'
require 'health_monitor/plugins/pagerduty'
require 'health_monitor/plugins/resurrector'
require 'health_monitor/plugins/tsdb'
require 'health_monitor/plugins/varz'
