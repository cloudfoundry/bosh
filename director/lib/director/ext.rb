# Copyright (c) 2009-2012 VMware, Inc.

module Resque
  def redis
    Bosh::Director::Config.redis
  end
end

class Object
 def to_openstruct
   self
 end
end

class Array
 def to_openstruct
   map { |el| el.to_openstruct }
 end
end

class Hash
  def recursive_merge!(other)
    self.merge!(other) do |_, old_value, new_value|
      if old_value.class == Hash && new_value.class == Hash
        old_value.recursive_merge!(new_value)
      else
        new_value
      end
    end
    self
  end

 def to_openstruct
   mapped = {}
   each { |key, value| mapped[key] = value.to_openstruct }
   OpenStruct.new(mapped)
 end
end

require "sequel/connection_pool/threaded"

class Sequel::ThreadedConnectionPool < Sequel::ConnectionPool

  alias_method :acquire_original, :acquire
  alias_method :release_original, :release

  def acquire(thread)
    logger = Bosh::Director::Config.logger
    result = acquire_original(thread)
    if logger
      logger.debug("Acquired connection: #{@allocated[thread].object_id}")
    end
    result
  end

  def release(thread)
    logger = Bosh::Director::Config.logger
    if logger
      logger.debug("Released connection: #{@allocated[thread].object_id}")
    end
    release_original(thread)
  end

end
