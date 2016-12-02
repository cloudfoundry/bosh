require 'bosh/dev/uri_provider'
require 'bosh/dev/command_helper'

module Bosh::Dev
  class ReleaseArtifact
    include CommandHelper

    def initialize(build_number, logger)
      @build_number = build_number
      @logger = logger
    end

    def name
      "bosh-#{@build_number}.tgz"
    end

    def promote
      stdout, stderr, status = exec_cmd("s3cmd --verbose cp #{source} #{destination}")
      raise "Failed to copy release artifact from #{source} to #{destination}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def promoted?
      _, _, status = exec_cmd("s3cmd info #{destination}")
      status.success?
    end

    private

    def source
      Bosh::Dev::UriProvider.pipeline_s3_path("#{@build_number}/release", name)
    end

    def destination
      Bosh::Dev::UriProvider.artifacts_s3_path('release', name)
    end
  end
end
