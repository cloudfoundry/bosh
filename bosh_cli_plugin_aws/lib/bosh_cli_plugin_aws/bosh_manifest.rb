module Bosh
  module Aws
    class BoshManifest < MicroboshManifest

      attr_reader :director_uuid

      def initialize(vpc_receipt, route53_receipt, director_uuid, options={})
        super(vpc_receipt, route53_receipt, options)
        @director_uuid = director_uuid
      end

      def file_name
        "bosh.yml"
      end

      def deployment_name
        "bosh"
      end

      def vip
        route53_receipt['elastic_ips']['bosh']['ips'][0] || warning('Missing vip field')
      end

      def bosh_deployment_name
        "vpc-bosh-#{name}"
      end

      def director_ssl_key
        certificate.key.gsub("\n", "\n        ")
      end

      def director_ssl_cert
        certificate.certificate.gsub("\n", "\n        ")
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
