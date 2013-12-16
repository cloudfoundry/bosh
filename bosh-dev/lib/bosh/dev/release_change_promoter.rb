require 'bosh/core/shell'
require 'bosh/dev/uri_provider'

module Bosh::Dev
  class ReleaseChangePromoter
    def initialize(build_number, candidate_sha, downloader)
      @build_number = build_number
      @candidate_sha = candidate_sha
      @download_adapter = downloader
    end

    def promote
      patch_uri = Bosh::Dev::UriProvider.release_patches_uri('', "#{@build_number}-final-release.patch")
      patch_file = Tempfile.new("#{@build_number}-final-release")
      @download_adapter.download(patch_uri, patch_file.path)

      shell = Bosh::Core::Shell.new

      shell.run("git checkout #{@candidate_sha}")

      # Remove any artifacts from Jenkins setup
      shell.run('git checkout .')
      shell.run('git clean --force')

      shell.run("git apply #{patch_file.path}")
      shell.run('git add -A :/')
      shell.run("git commit -m 'Adding final release for build #{@build_number}'")

      shell.run('git rev-parse HEAD')
    end
  end
end
