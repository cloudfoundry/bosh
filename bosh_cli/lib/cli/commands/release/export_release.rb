require 'cli/name_version_pair'
require 'cli/client/export_release_client'
require 'json'

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

        if status != :done
          task_report(status, task_id)
          return
        end

        task_result_file = director.get_task_result_log(task_id)
        task_result = JSON.parse(task_result_file)
        tarball_blobstore_id = task_result['blobstore_id']
        tarball_sha1 = task_result['sha1']

        tarball_file_name = "release-#{release.name}-#{release.version}-on-#{stemcell_os}-stemcell-#{stemcell.version}.tgz"
        tarball_file_path = File.join(Dir.pwd, tarball_file_name)

        nl
        progress_renderer.start(tarball_file_name, "downloading...")
        tmpfile = director.download_resource(tarball_blobstore_id)

        FileUtils.move(tmpfile, tarball_file_path)
        progress_renderer.finish(tarball_file_name, "downloaded")

        if file_checksum(tarball_file_path) != tarball_sha1
          err("Checksum mismatch for downloaded blob `#{tarball_file_path}'")
        end

        task_report(status, task_id, "Exported release `#{release.name.make_green}/#{release.version.make_green}` for `#{stemcell_os.make_green}/#{stemcell.version.make_green}`")
      end

      # Returns file SHA1 checksum
      # @param [String] path File path
      def file_checksum(path)
        Digest::SHA1.file(path).hexdigest
      end
    end
  end
end
