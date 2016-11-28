require 'bosh/dev'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class ArtifactsDownloader
    def initialize(download_adapter, logger)
      @download_adapter = download_adapter
      @logger = logger
    end

    def download_release(build_number, output_dir)
      file_name = "bosh-#{build_number}.tgz"

      remote_uri = Bosh::Dev::UriProvider.pipeline_uri("#{build_number}/release", file_name)
      local_path = File.join(output_dir, file_name)

      @download_adapter.download(remote_uri, local_path)
    end

    def download_stemcell(stemcell, output_dir)
      remote_uri = Bosh::Dev::UriProvider.pipeline_uri("#{stemcell.version}/bosh-stemcell/#{stemcell.infrastructure.name}", stemcell.name)
      local_path = File.join(output_dir, stemcell.name)

      @download_adapter.download(remote_uri, local_path)
    end
  end
end
