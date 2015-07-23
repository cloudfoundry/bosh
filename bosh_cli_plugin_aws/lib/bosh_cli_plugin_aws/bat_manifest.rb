require 'net/http'

module Bosh
  module AwsCliPlugin
    class BatManifest < MicroboshManifest
      attr_reader :stemcell_version, :director_uuid, :stemcell_name

      def initialize(vpc_receipt, route53_receipt, stemcell_version, director_uuid, stemcell_name)
        super(vpc_receipt, route53_receipt)
        @stemcell_version = stemcell_version
        @director_uuid = director_uuid
        @stemcell_name = stemcell_name
      end

      def file_name
        "bat.yml"
      end

      def deployment_name
        "bat"
      end

      def vip
        route53_receipt['elastic_ips']['bat']['ips'][0] || warning('Missing vip field')
      end

      def static_ip
        ENV.fetch('BOSH_AWS_STATIC_IP', '10.10.0.29')
      end

      def second_static_ip
        ENV.fetch('BOSH_AWS_SECOND_STATIC_IP', '10.10.0.30')
      end

      def to_y
        ERB.new(File.read(get_template("bat.yml.erb"))).result(binding)
      end

      def get_template(template)
        File.expand_path("../../../templates/#{template}", __FILE__)
      end

      private

      def reserved_ip_range
        env_range = ENV.fetch('BOSH_AWS_NETWORK_RESERVED', '')
        env_range.empty? ? '10.10.0.2 - 10.10.0.9' : env_range
      end

      def static_ip_range
        env_range = ENV.fetch('BOSH_AWS_NETWORK_STATIC', '')
        env_range.empty? ? '10.10.0.10 - 10.10.0.30' : env_range
      end
    end
  end
end
