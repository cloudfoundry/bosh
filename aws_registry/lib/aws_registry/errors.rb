# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSRegistry

  class Error < StandardError
    def self.code(code = nil)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; code(42); end

  class ConfigError < Error; code(101); end
  class ConnectionError < Error; code(202); end
end
