require 'bosh/dev'
require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitPromoter
    include CommandHelper

    def initialize(dir, logger)
      @dir = dir
      @logger = logger
    end

    def promote(commit_sha, stable_branch, origin = 'origin')
      raise ArgumentError, 'commit_sha is required' if commit_sha.to_s.empty?
      raise ArgumentError, 'stable_branch is required' if stable_branch.to_s.empty?

      stdout, stderr, status = exec_cmd("git push #{origin} #{commit_sha}:#{stable_branch}", @dir)
      raise "Failed to git push local #{commit_sha} to origin #{stable_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end
  end
end
