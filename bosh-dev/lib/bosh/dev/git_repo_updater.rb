require 'bosh/dev/command_helper'

module Bosh::Dev
  class GitRepoUpdater
    include CommandHelper

    def initialize(logger)
      @logger = logger
    end

    def update_directory(dir, commit_message)
      Dir.chdir(dir) do
        stdout, stderr, status = exec_cmd('git add .')
        raise "Failed adding untracked files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        # Terrible patch until we start working with a git abstraction rather than shelling out like fools
        # Check git status for "nothing to commit"...we know
        stdout, stderr, status = exec_cmd('git status')
        raise "Failed getting git repo status in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        return if stdout.match(/^nothing to commit.*working directory clean.*$/)

        stdout, stderr, status = exec_cmd("git commit -a -m '#{commit_message}'")
        raise "Failed committing modified files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        stdout, stderr, status = exec_cmd('git push')
        raise "Failed git pushing from #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
      end
    end
  end
end
