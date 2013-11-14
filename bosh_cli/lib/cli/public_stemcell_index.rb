require 'cli/public_stemcell'

module Bosh::Cli
  class PublicStemcellIndex
    def self.download(ui)
      index_url = 'https://s3.amazonaws.com/blob.cfblob.com/stemcells/public_stemcells_index.yml'

      http_client = HTTPClient.new
      response = http_client.get(index_url)
      status_code = response.http_header.status_code

      if status_code == HTTP::Status::OK
        index = Psych.load(response.body)
        index.delete('public_stemcells_index.yml') if index.has_key?('public_stemcells_index.yml')
        new(index)
      else
        ui.err("Received HTTP #{status_code} from #{index_url}.")
      end
    end

    def initialize(index)
      @index = index
    end

    def has_stemcell?(stemcell_name)
      @index.has_key?(stemcell_name)
    end

    def names
      @index.keys.sort
    end

    def find(stemcell_name)
      PublicStemcell.new(stemcell_name, @index[stemcell_name])
    end

    def each
      names.map { |stemcell_name| yield find(stemcell_name) }
    end
  end
end
