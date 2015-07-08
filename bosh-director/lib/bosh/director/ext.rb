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
  def recursive_merge(other)
    self.merge(other) do |_, old_value, new_value|
      if old_value.class == Hash && new_value.class == Hash
        old_value.recursive_merge(new_value)
      else
        new_value
      end
    end
  end

  def to_openstruct
    mapped = {}
    each { |key, value| mapped[key] = value.to_openstruct }
    OpenStruct.new(mapped)
  end
end
