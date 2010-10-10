module Bosh
  module Agent
    VERSION = '0.0.1'
  end
end

require 'logger'

require 'redis'
require "yajl"
require 'uuidtools'

require "agent/config"
require "agent/message/configure"
require "agent/handler"

module Bosh::Agent

  class << self
    def run(options = {})
      Runner.new(options).start
    end
  end

  class Runner < Struct.new(:config, :pubsub_redis, :redis)

    def initialize(options)
      self.config = Bosh::Agent::Config.configure(options)
    end

    def start
      $stdout.sync = true
      Bosh::Agent::Message::Configure.process(nil)
      Bosh::Agent::Handler.start
    end
  end

end

if __FILE__ == $0
  options = {
    "logging" => { "level" => "DEBUG" },
    "redis" => { "host" => "localhost" }
  }
  Bosh::Agent.run(options)
end
