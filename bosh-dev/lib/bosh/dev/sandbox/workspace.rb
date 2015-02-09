require 'bosh/dev'

module Bosh::Dev::Sandbox
  class Workspace
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    class << self
      def dir
        File.join(base_dir, "pid-#{Process.pid}")
      end

      def clean
        FileUtils.rm_rf(base_dir)
      end

      private

      def base_dir
        File.join(REPO_ROOT, 'tmp', 'integration-tests-workspace')
      end
    end
  end
end
