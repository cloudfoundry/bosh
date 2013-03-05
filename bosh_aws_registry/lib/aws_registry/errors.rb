# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry

  class Error < StandardError
    def self.code(code = 500)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; end

  class ConfigError < Error; end
  class ConnectionError < Error; end

  class AwsError < Error; end

  class InstanceError < Error; end
  class InstanceNotFound < Error; code(404); end
end
