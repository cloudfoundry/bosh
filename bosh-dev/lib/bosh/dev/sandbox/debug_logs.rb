module Bosh::Dev::Sandbox
  class DebugLogs
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    class << self
      def log_directory
        File.join(REPO_ROOT, 'tmp', 'integration-tests-logs')
      end

      def clean
        FileUtils.rm_rf(log_directory)
      end
    end
  end
end
