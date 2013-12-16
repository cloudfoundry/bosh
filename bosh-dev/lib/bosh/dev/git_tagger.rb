require 'open3'
require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev
  class GitTagger
    def initialize(logger)
      @logger = logger
    end

    def tag_and_push(sha, build_number)
      raise ArgumentError, 'sha is required' if sha.to_s.empty?
      raise ArgumentError, 'build_number is required' if build_number.to_s.empty?

      tag_name = "stable-#{build_number}"
      @logger.info("Tagging and pushing #{sha} as #{tag_name}")

      stdout, stderr, status = Open3.capture3('git', 'tag', '-a', tag_name, '-m', 'ci-tagged', sha)
      raise "Failed to tag #{sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = Open3.capture3('git', 'push', 'origin', '--tags')
      raise "Failed to push tags: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def stable_tag_for?(subject_sha)
      !!Bosh::Core::Shell.new.run("git fetch --tags && git tag --contains #{subject_sha}").match(/stable-/)
    end
  end
end
