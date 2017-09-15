module Bosh::Registry

  class Error < StandardError
    def self.code(code = 500)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; end

  class ConfigError < Error; end
  class ConnectionError < Error; end

  class AWSError < Error; end

  class InstanceError < Error; end
  class InstanceNotFound < Error; code(404); end

  class NotImplemented < Error; end
end