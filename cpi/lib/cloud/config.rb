require "forwardable"

module Bosh::Clouds
  class Config

    class << self
      extend Forwardable
      def_delegators :@delegate, :db, :logger, :uuid
    end

    def self.configure(config)
      @delegate = config
    end

  end
end
