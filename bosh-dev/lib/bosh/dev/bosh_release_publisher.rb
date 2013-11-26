require 'bosh/dev/build'

module Bosh
  module Dev
    class BoshReleasePublisher
      def self.setup_for(build)
        logger = Logger.new(STDERR)
        new(build, UploadAdapter.new(logger), DownloadAdapter.new(logger))
      end

      def initialize(build, uploader, downloader)
        @build = build
        @uploader = uploader
        @downloader = downloader
      end

      def publish
        release = Bosh::Dev::BoshRelease.build
        @build.upload_release(release)
        changes = Bosh::Dev::ReleaseChanges.new(@build.number, @uploader, @downloader)
        changes.stage
      end
    end
  end
end
