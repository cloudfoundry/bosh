module Bosh
  module Aws
    class BoshManifest < MicroboshManifest

      attr_reader :director_uuid

      def initialize(receipt, director_uuid)
        @receipt = receipt
        @director_uuid = director_uuid
      end

      def vip
        receipt['elastic_ips']['bosh']['ips'][0] || warning('Missing vip field')
      end

      # RSpec overloads to_yaml when you set up expectations on an object;
      # so to_y is just a way to get directly at the to_yaml implementation without fighting RSpec.
      def to_y
        ERB.new(File.read(get_template("bosh.yml.erb"))).result(binding)
      end

      def to_yaml
        to_y
      end
    end
  end
end