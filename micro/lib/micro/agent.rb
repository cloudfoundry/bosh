
require 'logger'
require 'blobstore_client'
require 'tempfile'
require 'ostruct'
require 'posix-spawn'
require 'monit_api'

module Bosh
  module Agent
    class MessageHandlerError < StandardError; end
    BOSH_APP = BOSH_APP_USER = BOSH_APP_GROUP = "vcap"
  end
end

require 'agent/ext'
require 'agent/util'
require 'agent/config'
require 'agent/version'
require 'agent/message/base'
require 'agent/message/apply'
require 'agent/monit'

module VCAP
  module Micro
    class Agent
      APPLY_SPEC = '/var/vcap/micro/apply_spec.yml'

      def self.apply(identity)
        agent = self.new(identity)
        agent.setup
        agent.apply
      end

      def self.start
        Agent.config
        Bosh::Agent::Monit.enabled = true
        Bosh::Agent::Monit.start
      end

      def self.config
        settings = {
          "configure" => true,
          "logging" => { "level" => "WARN" },
          "agent_id" => "micro",
          "base_dir" => "/var/vcap",
          "blobstore_options" => { "blobstore_path" => "/var/vcap/data/cache" },
          "blobstore_provider" => "local"
        }
        Bosh::Agent::Config.setup(settings)
      end

      def initialize(identity)
        @identity = identity
      end

      def setup
        FileUtils.mkdir_p('/var/vcap/data/log')

        Agent.config
        Bosh::Agent::Monit.setup_monit_user
        Agent.start

        load_spec
        update_spec
      end

      def load_spec
        @spec = YAML.load_file(APPLY_SPEC)
      end

      def update_spec
        subdomain = @identity.subdomain
        admins = @identity.admins

        properties = @spec['properties']

        unless @identity.configured?
          properties = VCAP::Micro::Settings.randomize_passwords(properties)
        end

        properties['domain'] = subdomain
        properties['cc']['admins'] = admins

        @spec['properties'] = properties
        @spec['networks'] = { "local" => { "ip" => "127.0.0.1" } }

        File.open(APPLY_SPEC, 'w') { |f| f.write(YAML.dump(@spec)) }
      end

      def apply
        Bosh::Agent::Message::Apply.process([@spec])
        monitor_start
      end

      def monitor_start
        started = []

        loop do
          status = Bosh::Agent::Monit.retry_monit_request(:status, :group => 'vcap')

          status.each do |name, data|
            if running_service?(data)
              unless started.include?(name)
                puts "Started: #{name}"
                started << name
              end
            end
          end

          break if status.reject { |name, data| running_service?(data) }.empty?
          sleep 1
        end
      end

      def running_service?(data)
        data[:monitor] == :yes && data[:status][:message] == "running"
      end

    end
  end
end
