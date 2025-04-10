module Bosh
  module Monitor
  end
end

begin
  require 'fiber'
rescue LoadError
  unless defined? Fiber
    warn 'FATAL: HealthMonitor requires Ruby implementation that supports fibers'
    exit 1
  end
end

require 'ostruct'
require 'set'

require 'async'
require 'async/http'
require 'io/stream'
require 'logging'
require 'nats/io/client'
require 'puma'
require 'puma/configuration'
require 'sinatra'
require 'securerandom'

# Helpers
require 'bosh/monitor/yaml_helper'

# Basic blocks
require 'bosh/monitor/agent'
require 'bosh/monitor/instance'
require 'bosh/monitor/deployment'
require 'bosh/monitor/auth_provider'
require 'bosh/monitor/config'
require 'bosh/monitor/core_ext'
require 'bosh/monitor/director'
require 'bosh/monitor/director_monitor'
require 'bosh/monitor/errors'
require 'bosh/monitor/metric'
require 'bosh/monitor/runner'
require 'bosh/monitor/version'

# Processing
require 'bosh/monitor/instance_manager'
require 'bosh/monitor/resurrection_manager'
require 'bosh/monitor/event_processor'

# HTTP endpoints
require 'bosh/monitor/api_controller'

# Protocols
require 'bosh/monitor/protocols/tcp_connection'
require 'bosh/monitor/protocols/tsdb_connection'
require 'bosh/monitor/protocols/graphite_connection'

# Events
require 'bosh/monitor/events/base'
require 'bosh/monitor/events/alert'
require 'bosh/monitor/events/heartbeat'

# Plugins
require 'bosh/monitor/plugins/base'
require 'bosh/monitor/plugins/dummy'
require 'bosh/monitor/plugins/http_request_helper'
require 'bosh/monitor/plugins/resurrector_helper'
require 'bosh/monitor/plugins/datadog'
require 'bosh/monitor/plugins/paging_datadog_client'
require 'bosh/monitor/plugins/email'
require 'bosh/monitor/plugins/graphite'
require 'bosh/monitor/plugins/json'
require 'bosh/monitor/plugins/logger'
require 'bosh/monitor/plugins/pagerduty'
require 'bosh/monitor/plugins/resurrector'
require 'bosh/monitor/plugins/riemann'
require 'bosh/monitor/plugins/tsdb'
require 'bosh/monitor/plugins/consul_event_forwarder'
require 'bosh/monitor/plugins/event_logger'
