require 'cli/client/compiled_packages_client'

module Bosh::Cli::Command
  class ImportCompiledPackages < Base
    usage 'import compiled_packages'
    desc 'Import compiled packages for a specific release and stemcell combination'
    def perform(exported_tar_path)
      auth_required
      show_current_state

      unless File.exist?(exported_tar_path)
        raise Bosh::Cli::CliError, 'Archive does not exist'
      end

      client = Bosh::Cli::Client::CompiledPackagesClient.new(director)
      status, task_id = client.import(exported_tar_path)
      task_report(status, task_id)
    end
  end
end
