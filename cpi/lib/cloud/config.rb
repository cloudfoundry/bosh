require "logger"

module Bosh::Clouds
  class Config

    class << self
      extend Forwardable

      def_delegators :@delegate, :db, :logger, :uuid

      def configure(config)
        @delegate = config
      end

    end
  end
end
