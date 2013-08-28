module Bosh::Dev
  class DirectorClient
    def initialize(options = {})
      @director_handle = Bosh::Cli::Director.new(
        options.fetch(:uri),
        options.fetch(:username),
        options.fetch(:password),
      )
    end

    def stemcells
      director_handle.list_stemcells
    end

    def has_stemcell?(name, version)
      stemcells.any? do |stemcell|
        stemcell['name'] == name && stemcell['version'] == version
      end
    end

    private

    attr_reader :director_handle
  end
end
