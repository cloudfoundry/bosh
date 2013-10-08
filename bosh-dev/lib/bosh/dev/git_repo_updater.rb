require 'open3'

module Bosh
  module Dev
    class GitRepoUpdater
      def update_directory(dir)
        Dir.chdir(dir) do
          stdout, stderr, status = Open3.capture3('git', 'add', '.')
          fail("Failed to git add untracked files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?

          stdout, stderr, status = Open3.capture3('git', 'commit', '-a', '-m', 'Autodeployer receipt file update')
          fail("Failed to commit modified files in #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?

          stdout, stderr, status = Open3.capture3('git', 'push')
          fail("Failed to git push from #{dir}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?
        end
      end
    end
  end
end
