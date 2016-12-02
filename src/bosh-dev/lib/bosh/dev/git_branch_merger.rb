require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitBranchMerger
    include CommandHelper

    def self.build
      new(
        Dir.pwd,
        Logging.logger(STDERR),
      )
    end

    def initialize(dir, logger)
      @dir = dir
      @logger = logger
    end

    def merge(source_sha, target_branch, commit_message)
      stdout, stderr, status = run_cmd("git fetch origin #{target_branch}")
      raise "Failed fetching branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = run_cmd("git checkout #{target_branch}")
      raise "Failed checking out branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = run_cmd("git merge #{source_sha} -m '#{commit_message}'")
      raise "Failed merging to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      stdout, stderr, status = run_cmd("git push origin #{target_branch}")
      raise "Failed pushing to branch #{target_branch}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def branch_contains?(branch_name, commit_sha)
      stdout, stderr, status = run_cmd("git fetch origin #{branch_name}")
      raise "Failed fetching branch #{branch_name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      _, _, status = run_cmd("git merge-base --is-ancestor #{commit_sha} remotes/origin/#{branch_name}")
      status.success?
    end

    def sha_does_not_include_latest_master?(candidate_sha)
      latest_sha, stderr, status = run_cmd('git rev-parse origin/master')
      raise "Failed fetching branch master: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      _, _, status = run_cmd("git log #{candidate_sha} | grep #{latest_sha.strip}")
      !status.success?
    end

    private

    def run_cmd(cmd)
      exec_cmd(cmd, @dir)
    end
  end
end
