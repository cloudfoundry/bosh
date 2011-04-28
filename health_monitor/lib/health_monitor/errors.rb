module Bosh::HealthMonitor

  class Error < StandardError
    def self.error_code(code = nil)
      define_method(:error_code) { code }
    end
  end

  class FatalError < Error; error_code(42); end

  class ConfigError < Error; error_code(101); end
  class DirectorError < Error; error_code(201); end

end
