require 'cli/client/compiled_packages_client'

module Bosh::Cli::Command
  class ImportCompiledPackages < Base
    usage 'import compiled_packages'
    desc 'Import compiled packages for a specific release and stemcell combination'

    def perform(exported_tar_path)
      auth_required

      client = Bosh::Cli::Client::CompiledPackagesClient.new(director)
      client.import(exported_tar_path)
    end
  end
end
