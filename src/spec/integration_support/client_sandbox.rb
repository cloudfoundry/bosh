require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'integration_support/workspace'

module IntegrationSupport
  class ClientSandbox
    class << self
      def workspace_dir
        IntegrationSupport::Workspace.dir
      end

      def base_dir
        File.join(workspace_dir, 'client-sandbox')
      end

      def home_dir
        File.join(base_dir, 'home')
      end

      def test_release_dir
        File.join(base_dir, 'test_release')
      end

      def manifests_dir
        File.join(base_dir, 'manifests')
      end

      def links_release_dir
        File.join(base_dir, 'links_release')
      end

      def multidisks_release_dir
        File.join(base_dir, 'multidisks_release')
      end

      def fake_errand_release_dir
        File.join(base_dir, 'fake_errand_release')
      end

      def bosh_work_dir
        File.join(base_dir, 'bosh_work_dir')
      end

      def bosh_config
        File.join(base_dir, 'bosh_config.yml')
      end

      def blobstore_dir
        File.join(base_dir, 'release_blobstore')
      end

      def temp_dir
        File.join(base_dir, 'release_blobstore')
      end
    end
  end
end

RSpec.configure do |config|
  tmp_dir = nil

  config.before do
    FileUtils.mkdir_p(IntegrationSupport::ClientSandbox.workspace_dir)
    tmp_dir = Dir.mktmpdir('spec-', IntegrationSupport::ClientSandbox.workspace_dir)

    allow(Dir).to receive(:tmpdir).and_return(tmp_dir)
  end

  config.after do |example|
    if example.exception
      puts "> Spec failed: #{example.location}"
      puts "> Test tmpdir: #{tmp_dir}\n"
      puts "#{example.exception.message}\n"
      puts '> ---------------'
    else
      FileUtils.rm_rf(tmp_dir) unless tmp_dir.nil?
    end
  end
end
