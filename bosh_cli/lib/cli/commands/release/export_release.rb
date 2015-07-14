require 'cli/name_version_pair'
require 'cli/client/export_release_client'

module Bosh::Cli::Command
  module Release
    class ExportRelease < Base

      usage 'export release'
      desc 'Export the compiled release to a tarball. Release should be in the form of {name}/{version} and stemcell should be in the form of {operating system name}/{stemcell version}'

      def export(release, stemcell)
        auth_required
        deployment_required
        manifest = Bosh::Cli::Manifest.new(deployment, director)
        manifest.load

        release = Bosh::Cli::NameVersionPair.parse(release)
        stemcell = Bosh::Cli::NameVersionPair.parse(stemcell)
        stemcell_os = stemcell.name

        client = Bosh::Cli::Client::ExportReleaseClient.new(director)
        status, task_id = client.export(manifest.name, release.name, release.version, stemcell_os, stemcell.version)
        task_report(status, task_id)
      end
    end
  end
end
