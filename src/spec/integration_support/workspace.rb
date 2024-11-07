require 'fileutils'
require 'integration_support/constants'

module IntegrationSupport
  class Workspace
    class << self
      def dir(*parts)
        File.join(pid_dir, *parts)
      end

      def sandbox_root
        File.join(pid_dir, '.sandbox')
      end

      def clean
        FileUtils.rm_rf(base_dir)
      end

      def start_uaa
        log_dir = dir('uaa_logs')
        FileUtils.mkdir_p(log_dir)

        UaaService.new(
          dir('sandbox'),
          log_dir,
          Logging.logger(File.open(File.join(log_dir, 'uaa_service.log'), 'w+'))
        ).tap { |s| s.start }
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
