module Bosh::Common::Template
  module Test
    class LinkInstance
      TEST_NAME = 'i-name'
      TEST_ID = 'jkl8098'
      TEST_INDEX = 4
      TEST_AZ = 'az4'
      TEST_ADDRESS = 'link.instance.fake.example.com'
      TEST_BOOTSTRAP = false

      attr_reader :name, :id, :index, :az, :address, :bootstrap

      def initialize(name: TEST_NAME,
                     id: TEST_ID,
                     index: TEST_INDEX,
                     az: TEST_AZ,
                     address: TEST_ADDRESS,
                     bootstrap: TEST_BOOTSTRAP)
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
end