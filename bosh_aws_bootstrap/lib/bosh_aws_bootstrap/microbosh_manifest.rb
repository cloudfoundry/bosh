module Bosh
  module Aws
    class MicroboshManifest
      attr_reader :config, :receipt

      def initialize(config, receipt)
        @config = config
        @receipt = receipt
      end

      def name
        config['name'] || warning('Missing name field')
      end

      def vip
        receipt['elastic_ips']['micro']['ips'][0] || warning('Missing vip field')
      end

      def subnet
        receipt['vpc']['subnets']['bosh'] || warning('Missing bosh subnet field')
      end

      def availability_zone
        config['vpc']['subnets']['bosh']['availability_zone']
      end

      def access_key_id
        config['aws']['access_key_id'] || warning('Missing aws access_key_id field')
      end

      def secret_access_key
        config['aws']['secret_access_key'] || warning('Missing aws secret_access_key field')
      end

      def region
        config['aws']['region'] || warning('Missing aws region field')
      end

      def private_key_path
        key_name = config['name']
        path = config['key_pairs'][key_name]
        unless path
          warning("Missing keypair '#{key_name}'")
          return nil
        end
        path.gsub(/\.pub$/, '')
      end

      # RSpec overloads to_yaml when you set up expectations on an object;
      # so to_y is just a way to get directly at the to_yaml implementation without fighting RSpec.
      def to_y
        ERB.new(File.read(get_template("micro_bosh.yml.erb"))).result(binding)
      end

      def to_yaml
        to_y
      end

      def get_template(template)
        File.expand_path("../../../templates/#{template}", __FILE__)
      end
    end
  end
end
