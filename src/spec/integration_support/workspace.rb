require 'fileutils'
require 'integration_support/constants'

module IntegrationSupport
  class Workspace
    class << self
      def dir(*parts)
        File.join(pid_dir, *parts)
      end

      def sandbox_root
        File.join(pid_dir, 'sandbox')
      end

      def clean
        FileUtils.rm_rf(base_dir)
      end

      def uaa_service
        @uaa_service ||=
          UaaService.new(dir('sandbox'), dir('uaa_logs'))
      end

      private

      def base_dir
        File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'tmp', 'integration-tests-workspace')
      end

      def pid_dir
        File.join(base_dir, "pid-#{Process.pid}")
      end
    end
  end
end
