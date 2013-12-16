module Bosh::Dev
  class GitBranchMerger
    def merge(target_branch, commit_message)
      shell = Bosh::Core::Shell.new
      shell.run('git fetch origin develop')

      shell.run("git merge origin/develop -m '#{commit_message}'")
      shell.run('git push origin HEAD:develop')
    end
  end
end
