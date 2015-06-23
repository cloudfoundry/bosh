require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitBranchMerger
    include CommandHelper

    def self.build
      new(
        Logging.logger(STDERR),
      )
    end

    def initialize(logger)
      @logger = logger
    end

    def merge(source_sha, target_branch, commit_message)
      stdout, stderr, status = exec_cmd("git fetch origin #{target_branch}")
      raise "Failed fetching branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git checkout #{target_branch}")
      raise "Failed checking out branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git merge #{source_sha} -m '#{commit_message}'")
      raise "Failed merging to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git push origin #{target_branch}")
      raise "Failed pushing to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def branch_contains?(branch_name, commit_sha)
      stdout, stderr, status = exec_cmd("git fetch origin #{branch_name}")
      raise "Failed fetching branch #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git checkout #{branch_name}")
      raise "Failed to git checkout #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd('git pull')
      raise "Failed to git pull: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git branch --contains #{commit_sha}")
      raise "Failed finding branches that contain sha #{commit_sha}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      branches = stdout.strip.lines.map(&:strip)
      # the currently checked out branch is prefixed with a star
      branches = branches.map{ |line| line.sub(/^\* /, '') }
      branches.include?(branch_name)
    end

    def verify_branch_was_merged(branch_name, candidate_sha)
      stdout, stderr, status = exec_cmd("git fetch origin #{branch_name}")
      raise "Failed fetching branch #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = exec_cmd("git branch --set-upstream-to=origin/#{branch_name} #{branch_name}")
      raise "Failed to set upstream for branch #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      _, _, status = exec_cmd("git branch --merged #{candidate_sha} | grep #{branch_name}")
      status.success?
    end
  end
end
