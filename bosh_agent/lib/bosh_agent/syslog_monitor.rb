# Copyright (c) 2009-2012 VMware, Inc.

require 'eventmachine'
require 'syslog_protocol'
require 'uuidtools'

module Bosh::Agent::SyslogMonitor

  PORT = 33331

  # severity level we publish in the nats alert
  SEVERITY = 4

  class Server < EventMachine::Connection
    include EM::Protocols::LineText2

    def initialize(nats, agent_id)
      @nats = nats
      @agent_id = agent_id
    end

    def receive_line(data)
      parsed = SyslogProtocol.parse(data)

      if parsed.content.end_with?('disconnected by user')
        title = 'SSH Logout'
      elsif parsed.content.include?('Accepted publickey for')
        title = 'SSH Login'
      else
        return
      end

      json = Yajl::Encoder.encode(
        {
          'id' => UUIDTools::UUID.random_create,
          'severity' => SEVERITY,
          'title' => title,
          'summary' => parsed.content,
          'created_at' => Time.now.to_i
        }
      )
      @nats.publish("hm.agent.alert.#{@agent_id}", json)
    end
  end

  def self.start(nats, agent_id)
    unless EM.reactor_running?
      raise Error, 'Cannot start syslog monitor as event loop is not running'
    end

    EventMachine::start_server '127.0.0.1', PORT, Server, nats, agent_id
  end
end
