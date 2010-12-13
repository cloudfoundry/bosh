module Ohm
  class Model

    def save!
      raise "Could not save #{self}: #{errors.pretty_inspect}" unless save
    end

  end
end

module Ohm
  def redis
    Bosh::Director::Config.redis
  end

  module_function :redis
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

class Redis
  class Client

    def logging(commands)
      return yield unless @logger && @logger.debug?

      t1 = Time.now
      begin
        commands.each do |name, *args|
          @logger.debug("Redis >> #{name.to_s.upcase} #{args.join(" ")}")
        end
        yield
      ensure
        @logger.debug("Redis >> %0.2fms" % ((Time.now - t1) * 1000))
      end
    end

  end
end