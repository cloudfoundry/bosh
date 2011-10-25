module Bosh::HealthMonitor

  class Error < StandardError
    def self.code(code = nil)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; code(42); end

  class ConfigError < Error; code(101); end
  class DirectorError < Error; code(201); end
  class ConnectionError < Error; code(202); end

  class EventProcessingError < Error; code(301); end
  class InvalidEvent < Error; code(302); end

  class PluginError < Error; code(401); end
end
