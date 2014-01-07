require 'open3'

module Bosh
  module Dev
    class GitRepoUpdater
      def update_directory(dir)
        Dir.chdir(dir) do
          stdout, stderr, status = Open3.capture3('git', 'add', '.')
          fail("Failed to git add untracked files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?

          # Terrible patch until we start working with a git abstraction rather than shelling out like fools
          # Check git status for "nothing to commit"...we know
          guard_stdout, guard_stderr, guard_status = Open3.capture3('git', 'status')
          fail("Failure to obtain git repo status in #{dir}: stdout: '#{guard_stdout}', stderr: '#{guard_stderr}'") unless guard_status.success?

          unless guard_stdout.match(/^nothing to commit.*working directory clean.*$/)
            stdout, stderr, status = Open3.capture3('git', 'commit', '-a', '-m', 'Autodeployer receipt file update')
            fail("Failed to commit modified files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?

            stdout, stderr, status = Open3.capture3('git', 'push')
            fail("Failed to git push from #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?
          end
        end
      end
    end
  end
end
