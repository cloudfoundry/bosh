require 'bosh/dev'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class ArtifactsDownloader
    def initialize(download_adapter, logger)
      @download_adapter = download_adapter
      @logger = logger
      @bucket_base_url = 'http://s3.amazonaws.com/bosh-jenkins-artifacts'
    end

    def download_release(build_number, output_dir)
      file_name = "bosh-#{build_number}.tgz"

      remote_uri = [@bucket_base_url, 'release', file_name].join('/')

      local_path = File.join(output_dir, file_name)

      @download_adapter.download(remote_uri, local_path)
    end

    def download_stemcell(build_target, output_dir)
      stemcell_name = 'bosh-stemcell'

      file_name = Bosh::Stemcell::ArchiveFilename.new(
        build_target.build_number.to_s,
        build_target.infrastructure,
        build_target.operating_system,
        stemcell_name,
        build_target.infrastructure_light?,
      ).to_s

      remote_uri = [
        @bucket_base_url,
        stemcell_name,
        build_target.infrastructure.name,
        file_name,
      ].join('/')

      local_path = File.join(output_dir, file_name)

      @download_adapter.download(remote_uri, local_path)
    end
  end
end
