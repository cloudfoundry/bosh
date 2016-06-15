require 'bosh/core/shell'
require 'bosh/dev/uri_provider'
require 'bosh/dev/command_helper'

module Bosh::Dev
  class ReleaseChangePromoter
    include CommandHelper

    def initialize(build_number, candidate_sha, downloader, skip_release_promotion, logger)
      @build_number = build_number
      @candidate_sha = candidate_sha
      @download_adapter = downloader
      @skip_release_promotion = skip_release_promotion
      @logger = logger
    end

    def promote
      stdout, stderr, status = exec_cmd("git checkout #{@candidate_sha}")
      raise "Failed to git checkout #{@candidate_sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      # Remove any artifacts from Jenkins setup
      stdout, stderr, status = exec_cmd('git checkout .')
      raise "Failed to remove jenkins setup artifacts: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd('git clean --force')
      raise "Failed to git clean: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      if @skip_release_promotion
        @candidate_sha
      else
        patch_uri = Bosh::Dev::UriProvider.release_patches_uri('', "#{@build_number}-final-release.patch")
        patch_file = Tempfile.new("#{@build_number}-final-release")
        @download_adapter.download(patch_uri, patch_file.path)

        stdout, stderr, status = exec_cmd("git apply #{patch_file.path}")
        raise "Failed to apply the release patch: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        stdout, stderr, status = exec_cmd('git add -A :/')
        raise "Failed to git add all the patched release files: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        stdout, stderr, status = exec_cmd("git commit -m 'Adding final release for build #{@build_number}'")
        raise "Failed to git commit the patched release files: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        stdout, stderr, status = exec_cmd('git rev-parse HEAD')
        raise "Failed to get the sha of the release commit: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        stdout.chomp
      end
    end
  end
end
