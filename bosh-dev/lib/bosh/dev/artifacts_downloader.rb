require 'bosh/dev'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class ArtifactsDownloader
    def initialize(download_adapter, logger)
      @download_adapter = download_adapter
      @logger = logger
      @stemcell_name = 'bosh-stemcell'
      @bucket_base_url = 'http://s3.amazonaws.com/bosh-jenkins-artifacts'
    end

    def download_release(build_number)
      remote_path = "http://s3.amazonaws.com/bosh-jenkins-artifacts/release/bosh-#{build_number}.tgz"
      @download_adapter.download(remote_path, "bosh-#{build_number}.tgz")
    end

    def download_stemcell(build_number, infrastructure, operating_system, light, output_dir)
      file_name = Bosh::Stemcell::ArchiveFilename.new(
        build_number.to_s,
        infrastructure,
        operating_system,
        @stemcell_name,
        light,
      ).to_s

      remote_uri = [
        @bucket_base_url,
        @stemcell_name,
        infrastructure.name,
        file_name,
      ].join('/')

      @download_adapter.download(remote_uri, File.join(output_dir, file_name))
    end
  end
end
