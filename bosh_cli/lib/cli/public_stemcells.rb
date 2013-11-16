require 'httpclient'
require 'rexml/document'

module Bosh::Cli
  class PublicStemcells
    class PublicStemcell
      def initialize(stemcell_key)
        @stemcell_key = stemcell_key
      end

      def name
        File.basename(@stemcell_key)
      end

      def version
        version_digits = @stemcell_key.gsub(/[^\d]/, '')
        version_digits.to_i
      end

      def variety
        name.gsub(version.to_s, '')
      end
    end

    def initialize
      @stemcell_url = 'https://bosh-jenkins-artifacts.s3.amazonaws.com'
    end

    def all
      response = HTTPClient.new.get(@stemcell_url)
      doc = REXML::Document.new(response.body)
      stemcell_keys = REXML::XPath.match(doc, "/ListBucketResult/Contents/Key[text()[starts-with(.,'bosh-stemcell/') and not(contains(.,'latest'))]]").map(&:text)
      stemcell_keys.map { |stemcell_key| PublicStemcell.new(stemcell_key) }
    end

    def recent
      stemcell_varietes = all.group_by(&:variety).values
      stemcell_varietes.map { |stemcells| stemcells.sort_by(&:version).last }
    end
  end
end
