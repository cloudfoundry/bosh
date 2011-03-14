
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
      def self.apply
        agent = new
        agent.setup
        agent.apply
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
      end

      def apply
        apply_spec = YAML.load_file('/var/vcap/micro/apply_spec.yml')
        Bosh::Agent::Message::Apply.process([apply_spec])
      end

    end
  end
end
