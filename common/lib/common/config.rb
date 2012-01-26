# Copyright (c) 2009-2012 VMware, Inc.

require "logger"

module Bosh
  class Config

    class << self

      def configure(config = {})
        if config["logger"]
          @logger = config["logger"]
        elsif config["logging"]
          @logger = Logger.new(config["logging"]["file"] || STDOUT)
          @logger.level = Logger.const_get((config["logging"]["level"] || "INFO").upcase)
        end
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
