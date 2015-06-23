require 'cli/name_version_pair'
require 'cli/client/export_release_client'

module Bosh::Cli::Command
  module Release
    class ExportRelease < Base

      # bosh create release
      usage 'export release'
      desc 'Export release to makes a tarball for the compiled release '

      def export(release, stemcell)
        auth_required
        show_current_state

        release = Bosh::Cli::NameVersionPair.parse(release)
        stemcell = Bosh::Cli::NameVersionPair.parse(stemcell)
        stemcell_os = stemcell.name

        client = Bosh::Cli::Client::ExportReleaseClient.new(director)
        status, task_id = client.export(release.name, release.version, stemcell_os, stemcell.version)
        task_report(status, task_id)
      end
    end
  end
end