require "common/config"

module Bosh::Clouds
  class Config

    class << self

      attr_accessor :logger, :uuid, :db

      def configure(config = {})
        Bosh::Config.configure(config)

        @logger = Bosh::Config.logger
        @uuid = config["uuid"]
        @db = config["db"]
      end

    end
  end
end
