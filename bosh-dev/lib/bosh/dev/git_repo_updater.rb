require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitRepoUpdater
    include CommandHelper

    def initialize(logger)
      @logger = logger
    end

    def update_directory(dir, commit_message)
      Dir.chdir(dir) do
        add_any_changes_to_index
        return if no_changes?

        commit_changes(commit_message)
        push
      end
    end

    private
    def add_any_changes_to_index
      stdout, stderr, status = exec_cmd('git add .')
      raise "Failed adding untracked files in #{Dir.pwd}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def no_changes?
      _, _, status = exec_cmd('git diff-index --quiet HEAD --')
      status.exitstatus == 0
    end

    def commit_changes(commit_message)
      stdout, stderr, status = exec_cmd("git commit -a -m '#{commit_message}'")
      raise "Failed committing modified files in #{Dir.pwd}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def push
      stdout, stderr, status = exec_cmd('git push')
      raise "Failed git pushing from #{Dir.pwd}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end
  end
end
