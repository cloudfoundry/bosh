module Bosh::Common::Template::Test
  class Link
    attr_reader :instances, :name, :properties, :address

    def initialize(name:, instances: [], properties: {}, address: nil)
      @instances = instances
      @name = name
      @properties = properties
      @address = address
    end

    def to_h
      {
        'instances' => instances.map(&:to_h),
        'name' => name,
        'properties' => properties,
        'address' => address,
      }
    end
  end
end
