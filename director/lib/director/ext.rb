module Ohm

  class ValidationException < StandardError
    attr_reader :errors

    def initialize(obj, errors)
      super("Could not save #{obj}: #{errors.pretty_inspect}")
      @errors = errors
    end
  end

  class Model

    def save!
      raise ValidationException.new(self, errors) unless save
    end

  end
end

module Ohm
  def redis
    Bosh::Director::Config.redis
  end

  module_function :redis

  module Validations

  protected
    def assert_unique_if_present(att, error = [att, :not_unique_if_present])
      if !send(att).to_s.empty?
        assert_unique(att, error)
      end
    end

  end
end

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
   map{ |el| el.to_openstruct }
 end
end

class Hash
  def recursive_merge!(other)
    self.merge!(other) do |_, old_value, new_value|
      if old_value.class == Hash
        old_value.recursive_merge!(new_value)
      else
        new_value
      end
    end
    self
  end

 def to_openstruct
   mapped = {}
   each{ |key,value| mapped[key] = value.to_openstruct }
   OpenStruct.new(mapped)
 end
end

module ActionPool
  class Pool
    def shutdown
        status(:closed)
        @logger.info("Pool is now shutting down")
        @queue.clear
        @queue.wait_empty
        @threads.each{|t|t.stop}
        @threads.each{|t|t.join}
        nil
    end
  end

  class Thread
    def join
      if @action_timeout.zero?
        @thread.join
      else
        @thread.join(@action_timeout)
        if @thread.alive?
          @thread.kill
          @thread.join
        end
      end
    end
  end
end