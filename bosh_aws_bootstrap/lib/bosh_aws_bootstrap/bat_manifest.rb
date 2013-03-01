require 'net/http'

module Bosh
  module Aws
    class BatManifest < MicroboshManifest

      attr_reader :stemcell_version, :director_uuid

      def initialize(receipt, stemcell_version, director_uuid)
        super(receipt)
        @stemcell_version = stemcell_version
        @director_uuid = director_uuid
      end

      def domain
        @receipt["vpc"]["domain"] || warning('Missing domain field')
      end

      def vip
        receipt['elastic_ips']['bat']['ips'][0] || warning('Missing vip field')
      end

      def to_y
        ERB.new(File.read(get_template("bat.yml.erb"))).result(binding)
      end

      #TODO DELETE ME SRSLY
      def get_template(template)
        File.expand_path("../../../templates/#{template}", __FILE__)
      end
    end
  end
end
