# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
end

require "logger"
require "time"
require "yaml"
require "set"

require "nats/client"
require "yajl"
require "uuidtools"
require "ostruct"
require "posix/spawn"
require "monit_api"
require "fileutils"
require "resolv"
require "ipaddr"
require 'httpclient'
require 'sigar'

require "common/exec"
require "common/properties"
require "encryption/encryption_handler"

require "bosh_agent/ext"
require "bosh_agent/version"

require "bosh_agent/template"
require "bosh_agent/errors"
require "bosh_agent/remote_exception"

require "bosh_agent/config"
require "bosh_agent/util"
require "bosh_agent/monit"

require "bosh_agent/infrastructure"
require "bosh_agent/platform"

require "bosh_agent/bootstrap"

require "bosh_agent/alert"
require "bosh_agent/alert_processor"
require "bosh_agent/smtp_server"
require "bosh_agent/heartbeat"
require "bosh_agent/heartbeat_processor"
require "bosh_agent/state"
require "bosh_agent/settings"
require "bosh_agent/file_matcher"
require "bosh_agent/file_aggregator"
require "bosh_agent/ntp"
require "bosh_agent/sshd_monitor"

require "bosh_agent/apply_plan/job"
require "bosh_agent/apply_plan/package"
require "bosh_agent/apply_plan/plan"

# TODO the message handlers will be loaded dynamically
require "bosh_agent/message/base"
require "bosh_agent/message/disk"
require "bosh_agent/message/state"
require "bosh_agent/message/drain"
require "bosh_agent/message/apply"
require "bosh_agent/message/compile_package"
require "bosh_agent/message/logs"
require "bosh_agent/message/ssh"

require "bosh_agent/handler"

YAML::ENGINE.yamler = 'syck' if defined?(YAML::ENGINE.yamler)

module Bosh::Agent

  BOSH_APP = BOSH_APP_USER = BOSH_APP_GROUP = "vcap"

  class << self
    def run(options = {})
      Runner.new(options).start
    end
  end

  class Runner < Struct.new(:config)

    def initialize(options)
      self.config = Bosh::Agent::Config.setup(options)
      @logger     = Bosh::Agent::Config.logger
    end

    def start
      $stdout.sync = true
      @logger.info("Starting agent #{Bosh::Agent::VERSION}...")

      if Config.configure
        @logger.info("Configuring agent...")
        # FIXME: this should not use message handler.
        # The whole thing should be refactored so that
        # regular code doesn't use RPC handlers other than
        # for responding to RPC.
        Bosh::Agent::Bootstrap.new.configure

        Bosh::Agent::Monit.enable
        Bosh::Agent::Monit.start
        Bosh::Agent::Monit.start_services
      else
        @logger.info("Skipping configuration step (use '-c' argument to configure on start) ")
      end

      if Config.mbus.start_with?("http")
        require "bosh_agent/http_handler"
        Bosh::Agent::HTTPHandler.start
      else
        Bosh::Agent::Handler.start
      end
    end
  end

end

if __FILE__ == $0
  options = {
    "configure"         => true,
    "logging"           => { "level" => "DEBUG" },
    "mbus"              => "nats://localhost:4222",
    "agent_id"          => "not_configured",
    "base_dir"          => "/var/vcap",
    "platform_name"     => "ubuntu",
    "blobstore_options" => {}
  }
  Bosh::Agent.run(options)
end
