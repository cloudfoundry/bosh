require 'bosh/core/shell'
require 'bosh/dev/uri_provider'

module Bosh::Dev
  class ReleaseChangePromoter
    def initialize(build_number, downloader)
      @build_number = build_number
      @download_adapter = downloader
    end

    def promote
      patch_uri = Bosh::Dev::UriProvider.release_patches_uri('', "#{@build_number}-final-release.patch")
      patch_file = Tempfile.new("#{@build_number}-final-release")
      @download_adapter.download(patch_uri, patch_file.path)

      shell = Bosh::Core::Shell.new

      shell.run("git apply #{patch_file.path}")
      shell.run("git add -A :/")
      shell.run("git commit -m 'Adding final release for build #{@build_number}'")
    end
  end
end
