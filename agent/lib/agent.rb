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

require "common/properties"
require "encryption/encryption_handler"

require "agent/ext"
require "agent/version"

require "agent/template"
require "agent/errors"
require "agent/remote_exception"

require "agent/config"
require "agent/util"
require "agent/monit"

require "agent/infrastructure"
require "agent/platform"

require "agent/bootstrap"

require "agent/alert"
require "agent/alert_processor"
require "agent/smtp_server"
require "agent/heartbeat"
require "agent/heartbeat_processor"
require "agent/state"
require "agent/file_matcher"
require "agent/file_aggregator"
require "agent/ntp"
require "agent/sshd_monitor"

require "agent/apply_plan/job"
require "agent/apply_plan/package"
require "agent/apply_plan/plan"

# TODO the message handlers will be loaded dynamically
require "agent/message/base"
require "agent/message/disk"
require "agent/message/state"
require "agent/message/drain"
require "agent/message/apply"
require "agent/message/compile_package"
require "agent/message/logs"
require "agent/message/ssh"

require "agent/handler"

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
        require "agent/http_handler"
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
