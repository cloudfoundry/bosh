module Bosh::HealthMonitor

  class Error < StandardError
    def self.error_code(code = nil)
      define_method(:error_code) { code }
    end
  end

  class FatalError < Error; error_code(42); end

  class ConfigError < Error; error_code(101); end
  class DirectorError < Error; error_code(201); end

  class AlertProcessingError < Error; error_code(301); end
  class InvalidAlert < Error; error_code(302); end
  class InvalidEvent < Error; error_code(303); end

  class DeliveryAgentError < Error; error_code(401); end

end
