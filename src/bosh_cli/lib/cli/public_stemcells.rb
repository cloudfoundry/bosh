require 'httpclient'
require 'rexml/rexml'
REXML.autoload :Document, 'rexml/document'

require 'cli/public_stemcell'

module Bosh::Cli
  class PublicStemcells
    PUBLIC_STEMCELLS_BASE_URL = 'https://bosh-jenkins-artifacts.s3.amazonaws.com'

    def has_stemcell?(stemcell_filename)
      all.any? { |stemcell| stemcell.name == stemcell_filename }
    end

    def find(stemcell_filename)
      all.detect { |stemcell| stemcell.name == stemcell_filename }
    end

    def all
      response = HTTPClient.new.get(PUBLIC_STEMCELLS_BASE_URL, {'prefix' => 'bosh-stemcell'})
      doc = REXML::Document.new(response.body)
      stemcells_tags = parse_document(doc)
      stemcells = parse_stemcells(stemcells_tags)

      while is_truncated(doc)
        response = HTTPClient.new.get(PUBLIC_STEMCELLS_BASE_URL, {
          'prefix' => 'bosh-stemcell',
          'marker' => stemcells_tags.last.get_text('Key').value
        })

        doc = REXML::Document.new(response.body)
        stemcells_tags = parse_document(doc)
        stemcells += parse_stemcells(stemcells_tags)
      end

      stemcells
    end

    def recent
      stemcell_varietes = all.reject(&:legacy?).group_by(&:variety).values
      stemcell_varietes.map { |stemcells| stemcells.sort_by(&:version).last }
    end

    private

    def parse_document(doc)
      REXML::XPath.match(doc, "/ListBucketResult/Contents[Key[text()[not(contains(.,'latest'))]]]")
    end

    def parse_stemcells(stemcell_tags)
      stemcell_tags.map do |stemcell_tag|
        stemcell_key = stemcell_tag.get_text('Key').value
        stemcell_size = Integer(stemcell_tag.get_text('Size').value)

        PublicStemcell.new(stemcell_key, stemcell_size)
      end
    end

    def is_truncated(doc)
      REXML::XPath.match(doc, "/ListBucketResult/IsTruncated").first.get_text == 'true'
    end
  end
end
