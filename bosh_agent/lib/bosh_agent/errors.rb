# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  class Error < StandardError; end

  class FatalError < Error; end
  class StateError < Error; end
  class UnimplementedMethod < FatalError; end
  class DiskNotFoundError < FatalError; end

  class MessageHandlerError < Error
    attr_reader :blob
    def initialize(message, blob=nil)
      super(message)
      @blob = blob
    end
  end

  class UnknownMessage < Error; end
  class LoadSettingsError < Error; end

  class HeartbeatError < StandardError; end

end
