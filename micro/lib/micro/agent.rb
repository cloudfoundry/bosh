
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
        Bosh::Agent::Monit.start_services(60)
      end

      def self.config
        settings = {
          "configure" => true,
          "logging" => {
              "level" => "DEBUG",
              "file" => "/var/vcap/sys/log/micro/agent.log"
            },
          "agent_id" => "micro",
          "base_dir" => "/var/vcap",
          "platform_name" => "ubuntu",
          "blobstore_options" => { "blobstore_path" => "/var/vcap/data/cache" },
          "blobstore_provider" => "local"
        }
        logdir = File.dirname(settings['logging']['file'])
        FileUtils.mkdir_p(logdir) unless Dir.exist?(logdir)
        Bosh::Agent::Config.setup(settings)
      end

      def self.randomize_passwords
        spec = YAML.load_file(APPLY_SPEC)
        properties = spec['properties']
        properties = VCAP::Micro::Settings.randomize_passwords(properties)
        spec['properties'] = properties
        File.open(APPLY_SPEC, 'w') { |f| f.write(YAML.dump(spec)) }
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

        properties['domain'] = subdomain
        properties['cc']['srv_api_uri'] = "http://api.#{subdomain}"
        properties['cc']['admins'] = admins

        env = properties['env']
        if @identity.proxy.url.empty?
          if env
            env.delete('http_proxy')
            env.delete('https_proxy')
            env.delete('no_proxy')
          end
        else
          unless env
            env = properties['env'] = {}
          end
          env['http_proxy'] = @identity.proxy.url
          env['https_proxy'] = @identity.proxy.url
          env['no_proxy'] = ".#{subdomain},127.0.0.1/8,localhost"
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

        # TODO change start_service() and friends to take an retries argument
        # Bosh::Agent::Monit.retry_monit_request(60) do |client|
        #   client.start(:group => Bosh::Agent::BOSH_APP_GROUP)
        # end
        Bosh::Agent::Monit.start_services(60)

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
