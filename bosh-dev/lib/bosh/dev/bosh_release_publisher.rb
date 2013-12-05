require 'bosh/dev/build'
require 'bosh/dev/release_change_stager'
require 'bosh/dev/upload_adapter'

module Bosh
  module Dev
    class BoshReleasePublisher
      def self.setup_for(build)
        new(build, UploadAdapter.new)
      end

      def initialize(build, uploader)
        @build = build
        @uploader = uploader
      end

      def publish
        release = BoshRelease.build
        @build.upload_release(release)
        changes = ReleaseChangeStager.new(Dir.pwd, @build.number, @uploader)
        changes.stage
      end
    end
  end
end
