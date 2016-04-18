require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Nginx
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))
    RELEASE_ROOT = File.join(REPO_ROOT, 'release')

    def initialize(runner = Bosh::Core::Shell.new)
      @runner = runner
      @working_dir = File.join(REPO_ROOT, 'tmp', 'integration-nginx-work')
      @install_dir = File.join(REPO_ROOT, 'tmp', 'integration-nginx')
    end

    def install
      sync_release_blobs
      compile
    end

    def executable_path
      File.join(@install_dir, 'sbin', 'nginx')
    end

    private

    def sync_release_blobs
      Dir.chdir(RELEASE_ROOT) { @runner.run('bundle exec bosh sync blobs') }
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(@working_dir)
      FileUtils.rm_rf(@install_dir)

      FileUtils.mkdir_p(@working_dir)
      FileUtils.mkdir_p(@install_dir)

      # on El Capitan, the compilation of nginx fails on openssl compilation step
      # we need to set LIBRARY_PATH so the linker can find the OpenSSL Dynamic Libraries
      # that have been installed with `brew link openssl --force`
      ENV['LIBRARY_PATH'] = '/usr/local/opt/openssl/lib' if (/darwin/ =~ RUBY_PLATFORM)

      # Make sure packaging script has its own blob copies so that blobs/ directory is not affected
      nginx_blobs_path = File.join(RELEASE_ROOT, 'blobs', 'nginx')
      @runner.run("cp -R #{nginx_blobs_path} #{File.join(@working_dir)}")

      Dir.chdir(@working_dir) do
        packaging_script_path = File.join(RELEASE_ROOT, 'packages', 'nginx', 'packaging')
        @runner.run("bash #{packaging_script_path}", env: {
          'BOSH_INSTALL_TARGET' => @install_dir,
        })
      end
    end
  end
end
