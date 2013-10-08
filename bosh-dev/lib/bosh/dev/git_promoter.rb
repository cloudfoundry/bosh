require 'open3'
require 'bosh/dev'

module Bosh::Dev
  class GitPromoter
    def initialize(logger)
      @logger = logger
    end

    def promote(dev_branch, stable_branch)
      raise ArgumentError, 'dev_branch is required' if dev_branch.to_s.empty?
      raise ArgumentError, 'stable_branch is required' if stable_branch.to_s.empty?

      @logger.info("Promoting local git branch #{dev_branch} to remote branch #{stable_branch}")

      stdout, stderr, status = Open3.capture3('git', 'push', 'origin', "#{dev_branch}:#{stable_branch}")
      raise "Failed to git push local #{dev_branch} to origin #{stable_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end
  end
end
