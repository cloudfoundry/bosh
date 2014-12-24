require 'bosh/dev'

module Bosh::Dev::Sandbox
  class DebugLogs
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    class << self
      def logs_dir
        File.join(base_dir, "pid-#{Process.pid}")
      end

      def clean
        FileUtils.rm_rf(base_dir)
      end

      def base_dir
        File.join(REPO_ROOT, 'tmp', 'integration-tests-logs')
      end
    end
  end
end
