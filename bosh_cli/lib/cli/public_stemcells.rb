require 'httpclient'
require 'rexml/document'

module Bosh::Cli
  class PublicStemcells
    class PublicStemcell
      attr_reader :size

      def initialize(key, size)
        @key = key
        @size = size
      end

      def name
        File.basename(@key)
      end

      def version
        version_digits = @key.gsub(/[^\d]/, '')
        version_digits.to_i
      end

      def variety
        name.gsub(version.to_s, '')
      end

      def url
        "#{PublicStemcells::PUBLIC_STEMCELLS_BASE_URL}/#{@key}"
      end
    end

    PUBLIC_STEMCELLS_BASE_URL = 'https://bosh-jenkins-artifacts.s3.amazonaws.com'

    def all
      response = HTTPClient.new.get(PUBLIC_STEMCELLS_BASE_URL)
      doc = REXML::Document.new(response.body)
      stemcell_tags = REXML::XPath.match(doc, "/ListBucketResult/Contents[Key[text()[starts-with(.,'bosh-stemcell/') and not(contains(.,'latest'))]]]")

      stemcell_tags.map do |stemcell_tag|
        stemcell_key = stemcell_tag.get_text('Key').value
        stemcell_size = Integer(stemcell_tag.get_text('Size').value)

        PublicStemcell.new(stemcell_key, stemcell_size)
      end
    end

    def recent
      stemcell_varietes = all.group_by(&:variety).values
      stemcell_varietes.map { |stemcells| stemcells.sort_by(&:version).last }
    end
  end
end
