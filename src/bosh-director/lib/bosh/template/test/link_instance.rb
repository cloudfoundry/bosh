module Bosh::Template::Test
  class LinkInstance
    attr_reader :name, :id, :index, :az, :address, :bootstrap

    def initialize(
      name: 'i-name',
        id: 'jkl8098',
        index: 4,
        az: 'az4',
        address: 'link.instance.address.com',
        bootstrap: false)
      @bootstrap = bootstrap
      @address = address
      @az = az
      @index = index
      @id = id
      @name = name
    end

    def to_h
      {
        'name' => name,
        'id' => id,
        'index' => index,
        'az' => az,
        'address' => address,
        'bootstrap' => bootstrap
      }
    end
  end
end