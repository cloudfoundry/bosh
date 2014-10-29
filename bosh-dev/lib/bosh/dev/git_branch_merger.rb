require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitBranchMerger
    include CommandHelper

    def initialize(logger)
      @logger = logger
    end

    def merge(target_branch, commit_message)
      stdout, stderr, status = exec_cmd("git fetch origin #{target_branch}")
      raise "Failed fetching branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git merge origin/#{target_branch} -m '#{commit_message}'")
      raise "Failed merging to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git push origin HEAD:#{target_branch}")
      raise "Failed pushing to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def branch_contains?(branch_name, commit_sha)
      stdout, stderr, status = exec_cmd("git fetch #{branch_name}")
      raise "Failed fetching branch #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("'git branch --contains #{commit_sha}")
      raise "Failed finding branches that contain sha #{commit_sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout.lines.map(&:chomp).include?(branch_name)
    end
  end
end
