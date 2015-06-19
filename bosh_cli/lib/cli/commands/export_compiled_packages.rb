require 'fileutils'
require 'cli/name_version_pair'
require 'cli/client/compiled_packages_client'

module Bosh::Cli::Command
  class ExportCompiledPackages < Base
    usage 'export compiled_packages'
    desc 'Download compiled packages for a specific release and stemcell combination'
    def perform(release, stemcell, download_dir)
      auth_required
      show_current_state

      release = Bosh::Cli::NameVersionPair.parse(release)
      stemcell = Bosh::Cli::NameVersionPair.parse(stemcell)

      unless Dir.exists?(download_dir)
        err("Directory `#{download_dir}' must exist.")
      end

      download_file_name = "#{release.name}-#{release.version}-#{stemcell.name}-#{stemcell.version}.tgz"
      download_path = File.join(download_dir, download_file_name)

      if File.exists?(download_path)
        err("File `#{download_path}' already exists.")
      end

      client = Bosh::Cli::Client::CompiledPackagesClient.new(director)
      tmp_path = client.export(release.name, release.version, stemcell.name, stemcell.version)
      FileUtils.mv(tmp_path, download_path)

      say("Exported compiled packages to `#{download_path.make_green}'.")
    end
  end
end
