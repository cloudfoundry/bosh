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
