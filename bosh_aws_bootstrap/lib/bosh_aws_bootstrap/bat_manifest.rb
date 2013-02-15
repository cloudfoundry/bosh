require 'net/http'

module Bosh
  module Aws
    class BatManifest < MicroboshManifest

      attr_reader :stemcell_version

      def initialize(config, receipt, stemcell_version)
        super(config,receipt)
        @stemcell_version = stemcell_version
      end

      def director_uuid
        YAML.load(Net::HTTP.get(URI.parse("http://micro.#{domain}:25555/info")))["uuid"]
      end

      def domain
        @receipt["vpc"]["domain"] || warning('Missing domain field')
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