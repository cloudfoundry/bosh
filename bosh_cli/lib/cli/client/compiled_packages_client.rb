module Bosh::Cli::Client
  class CompiledPackagesClient
    def initialize(director)
      @director = director
    end

    # Assuming that stemcell name does not have '/' in it
    def export(release_name, release_version, stemcell_name, stemcell_version)
      path = "/stemcells/#{stemcell_name}/#{stemcell_version}/releases/#{release_name}/#{release_version}/compiled_packages"
      _, file_path, _ = @director.get(path, nil, nil, {}, file: true)
      file_path
    end
  end
end
