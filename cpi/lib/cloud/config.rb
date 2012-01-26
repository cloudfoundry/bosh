module Bosh::Clouds
  class Config

    class << self

      attr_accessor :uuid, :db

      def configure(config = {})
        if config["logger"]
          @logger = config["logger"]
        elsif config["logging"]
          @logger = Logger.new(config["logging"]["file"] || STDOUT)
          @logger.level = Logger.const_get((config["logging"]["level"] || "INFO").upcase)
        end

        @uuid = config["uuid"]
        @db = config["db"]
      end

      def logger
        if @logger.nil?
          @logger = Logger.new(STDOUT)
          @logger.level = Logger::INFO
        end
        @logger
      end

      def logger=(logger)
        @logger = logger
      end

    end
  end
end
