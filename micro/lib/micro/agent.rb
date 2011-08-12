
require 'logger'
require 'blobstore_client'
require 'tempfile'
require 'ostruct'
require 'posix-spawn'
require 'monit_api'

module Bosh
  module Agent
    BOSH_APP = BOSH_APP_USER = BOSH_APP_GROUP = "vcap"
  end
end

require 'agent/ext'
require 'agent/util'
require 'agent/config'
require 'agent/errors'
require 'agent/version'
require 'agent/message/base'
require 'agent/message/apply'
require 'agent/platform'
require 'agent/monit'
require 'agent/state'
require 'agent/template'
require 'agent/platform'
require 'agent/platform/ubuntu'
require 'agent/platform/ubuntu/logrotate'


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
        Bosh::Agent::Monit.start_services
      end

      def self.config
        settings = {
          "configure" => true,
          "logging" => { "level" => "WARN" },
          "agent_id" => "micro",
          "base_dir" => "/var/vcap",
          "platform_name" => "ubuntu",
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
        properties['cc']['srv_api_uri'] = "http://api.#{subdomain}"
        properties['cc']['admins'] = admins

        if @identity.proxy.url.empty? && properties['env']
          properties['env'].delete('http_proxy')
          properties['env'].delete('https_proxy')
          properties['env'].delete('no_proxy')
        else
          properties['env'] = {} unless properties['env']
          properties['env']['http_proxy'] = @identity.proxy.url
          properties['env']['https_proxy'] = @identity.proxy.url
          properties['env']['no_proxy'] = ".#{subdomain},127.0.0.1/8,localhost"
        end

        @spec['properties'] = properties
        @spec['networks'] = { "local" => { "ip" => "127.0.0.1" } }

        File.open(APPLY_SPEC, 'w') { |f| f.write(YAML.dump(@spec)) }
      end

      def apply
        Bosh::Agent::Message::Apply.process([@spec])
        monitor_start
      end

      # start monitoring all services and then go into a loop
      # to print out the names of the started services
      def monitor_start
        started = []

        Bosh::Agent::Monit.start_services

        loop do
          status = Bosh::Agent::Monit.retry_monit_request do |client|
            client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
          end

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
