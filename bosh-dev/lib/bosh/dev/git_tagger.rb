require 'bosh/dev'
require 'bosh/dev/command_helper'
require 'bosh/core/shell'

module Bosh::Dev
  class GitTagger
    include CommandHelper

    def initialize(logger)
      @logger = logger
    end

    def tag_and_push(sha, build_number)
      raise ArgumentError, 'sha is required' if sha.to_s.empty?
      raise ArgumentError, 'build_number is required' if build_number.to_s.empty?

      tag_name = stable_tag_name(build_number)
      @logger.info("Tagging and pushing #{sha} as #{tag_name}")

      stdout, stderr, status = exec_cmd("git tag -a #{tag_name} -m ci-tagged #{sha}")
      raise "Failed to tag #{sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd('git push origin --tags')
      raise "Failed to push tags: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def stable_tag_for?(commit_sha)
      stdout, stderr, status = exec_cmd('git fetch --tags')
      raise "Failed to fetch tags: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git tag --contains #{commit_sha}")
      raise "Failed to get tags that contain the commit sha #{commit_sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout.include?('stable-')
    end

    def tag_sha(tag_name)
      stdout, stderr, status = exec_cmd('git fetch --tags')
      raise "Failed to fetch tags: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git rev-parse #{tag_name}^{}")
      raise "Failed to get sha of tag #{tag_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
      stdout.strip
    end

    def stable_tag_sha(commit_sha)
      tag_sha(stable_tag_name(commit_sha))
    end

    def stable_tag_name(build_number)
      "stable-#{build_number}"
    end
  end
end
