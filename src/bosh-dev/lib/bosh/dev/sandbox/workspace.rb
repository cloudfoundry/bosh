require 'bosh/dev'
require 'fileutils'

module Bosh::Dev::Sandbox
  class Workspace
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    def assets_dir
      File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)
    end

    def asset_path(asset_file_name)
      File.join(assets_dir, asset_file_name)
    end

    def repo_root
      REPO_ROOT
    end

    def repo_path(file_path)
      File.join(repo_root, file_path)
    end

    class << self
      def dir
        File.join(base_dir, "pid-#{Process.pid}")
      end

      def clean
        FileUtils.rm_rf(base_dir)
      end

      def start_uaa
        log_dir = File.join(dir, 'uaa_logs')
        FileUtils.mkdir_p(log_dir)
        uaa_log_file = File.open(File.join(log_dir, 'uaa_service.log'), 'w+')
        logger = Logging.logger(uaa_log_file)
        uaa_service = UaaService.new(File.join(dir, 'sandbox'), log_dir, logger)
        uaa_service.start
        uaa_service
      end

      private

      def base_dir
        File.join(REPO_ROOT, 'tmp', 'integration-tests-workspace')
      end
    end
  end
end
