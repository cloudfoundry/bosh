module Bosh::Monitor
  class Metric

    attr_accessor :name
    attr_accessor :value
    attr_accessor :timestamp
    attr_accessor :tags

    def initialize(name, value, timestamp, tags)
      @name = name
      @value = value
      @timestamp = timestamp
      @tags = tags
    end

    def to_hash
      {
          :name => @name,
          :value => @value.to_s,
          :timestamp => @timestamp.to_i,
          :tags => @tags
      }
    end
  end
end
