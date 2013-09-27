require 'net/http'

module Bosh
  module Aws
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

      def domain
        vpc_receipt["vpc"]["domain"] || warning('Missing domain field')
      end

      def vip
        route53_receipt['elastic_ips']['bat']['ips'][0] || warning('Missing vip field')
      end

      def to_y
        ERB.new(File.read(get_template("bat.yml.erb"))).result(binding)
      end

      def get_template(template)
        File.expand_path("../../../templates/#{template}", __FILE__)
      end
    end
  end
end
