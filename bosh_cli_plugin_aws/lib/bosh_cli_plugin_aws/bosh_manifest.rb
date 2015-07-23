module Bosh
  module AwsCliPlugin
    class BoshManifest < MicroboshManifest

      attr_reader :director_uuid, :rds_receipt

      attr_accessor :stemcell_name

      def initialize(vpc_receipt, route53_receipt, director_uuid, rds_receipt, options={})
        super(vpc_receipt, route53_receipt, options)
        @director_uuid = director_uuid
        @rds_receipt = rds_receipt
        @stemcell_name = 'bosh-aws-xen-ubuntu'
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

      def bosh_rds_properties
        rds_receipt['deployment_manifest']['properties']['bosh']
      end

      def bosh_rds_host
        bosh_rds_properties['address']
      end

      def bosh_rds_port
        bosh_rds_properties['port']
      end

      def bosh_rds_password
        bosh_rds_properties['roles'].first['password']
      end

      def bosh_rds_user
        bosh_rds_properties['roles'].first['name']
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
