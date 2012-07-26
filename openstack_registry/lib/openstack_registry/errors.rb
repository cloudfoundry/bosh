# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::OpenstackRegistry

  class Error < StandardError
    def self.code(code = 500)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; end

  class ConfigError < Error; end
  class ConnectionError < Error; end

  class OpenstackError < Error; end

  class ServerError < Error; end
  class ServerNotFound < Error; code(404); end
end
