require 'logger'
require 'bosh/dev'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  class ArtifactsDownloader
    def initialize
      @download_adapter = DownloadAdapter.new(Logger.new(STDERR))
    end

    def download_release(build_number)
      remote_path = "http://s3.amazonaws.com/bosh-jenkins-artifacts/release/bosh-#{build_number}.tgz"
      download_adapter.download(remote_path, "bosh-#{build_number}.tgz")
    end

    def download_stemcell(build_number)
      remote_path = "http://s3.amazonaws.com/bosh-jenkins-artifacts/bosh-stemcell/aws/light-bosh-stemcell-#{build_number}-aws-xen-ubuntu.tgz"
      download_adapter.download(remote_path, "light-bosh-stemcell-#{build_number}-aws-xen-ubuntu.tgz")
    end

    private

    attr_reader :download_adapter
  end
end
