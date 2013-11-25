require 'httpclient'
require 'rexml/document'

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
      stemcell_varietes = all.reject(&:legacy?).group_by(&:variety).values
      stemcell_varietes.map { |stemcells| stemcells.sort_by(&:version).last }
    end
  end
end
