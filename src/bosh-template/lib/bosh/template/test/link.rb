module Bosh::Template::Test
  class Link
    attr_reader :instances, :name, :properties

    def initialize(name:, instances: [], properties: {})
      @instances = instances
      @name = name
      @properties = properties
    end

    def to_h
      {
        'instances' => instances.map(&:to_h),
        'name' => name,
        'properties' => properties,
      }
    end
  end
end