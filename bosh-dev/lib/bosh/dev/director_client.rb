module Bosh::Dev
  class DirectorClient
    def initialize(options={})
      @director_handle = options.fetch(:director_handle) {
        Bosh::Cli::Director.new(
            options.fetch(:uri),
            options.fetch(:username),
            options.fetch(:password)
        )
      }
    end

    def stemcells
      director_handle.list_stemcells
    end

    private

    attr_reader :director_handle

  end
end
