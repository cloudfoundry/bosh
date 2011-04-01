
require 'logger'
require 'blobstore_client'
require 'tempfile'
require 'ostruct'
require 'posix-spawn'

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
require 'agent/message/apply'

module VCAP
  module Micro
    class Agent
      APPLY_SPEC = '/var/vcap/micro/apply_spec.yml'

      def self.apply(identity)
        agent = self.new(identity)
        agent.setup
        agent.apply
      end

      def initialize(identity)
        @identity = identity
      end

      def setup
        FileUtils.mkdir_p('/var/vcap/data/log')

        settings = {
          "configure" => true,
          "logging" => { "level" => "WARN" },
          "agent_id" => "micro",
          "base_dir" => "/var/vcap",
          "blobstore_options" => { "blobstore_path" => "/var/vcap/data/cache" },
          "blobstore_provider" => "local"
        }
        Bosh::Agent::Config.setup(settings)

        load_spec
        update_spec
      end

      def load_spec
        @spec = YAML.load_file(APPLY_SPEC)
      end

      def apply
        Bosh::Agent::Message::Apply.process([@spec])
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

        File.open(APPLY_SPEC, 'w') { |f| f.write(YAML.dump(@spec)) }
      end

    end
  end
end
