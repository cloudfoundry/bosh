require 'open3'

module Bosh
  module Dev
    class GitPromoter
      def promote(dev_branch, stable_branch)
        fail('dev_branch is required') if dev_branch.to_s.empty?
        fail('stable_branch is required') if stable_branch.to_s.empty?
        stdout, stderr, status = Open3.capture3('git', 'push', 'origin', "#{dev_branch}:#{stable_branch}")
        fail("Failed to git push local #{dev_branch} to origin #{stable_branch}: stdout: '#{stdout}', stderr: '#{stderr}'") unless status.success?
      end
    end
  end
end