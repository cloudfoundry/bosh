require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Nginx
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))
    RELEASE_ROOT = File.join(REPO_ROOT, '..')

    def initialize(runner = Bosh::Core::Shell.new)
      @runner = runner
      @working_dir = File.join(REPO_ROOT, 'tmp', 'integration-nginx-work')
      @install_dir = File.join(REPO_ROOT, 'tmp', 'integration-nginx')
    end

    def install
      sync_release_blobs
      if blob_has_changed
        compile
      else
        puts 'Skipping compiling nginx because shasums have not changed'
      end
    end

    def executable_path
      File.join(@install_dir, 'sbin', 'nginx')
    end

    private

    def blob_has_changed
      release_nginx_path = File.join(RELEASE_ROOT, 'blobs', 'nginx')
      blobs_shasum = shasum(release_nginx_path)
      working_dir_nginx_path = "#{@working_dir}/nginx"
      sandbox_copy_shasum = shasum(working_dir_nginx_path)

      blobs_shasum.sort != sandbox_copy_shasum.sort
    end

    def shasum(directory)
      output = @runner.run("find #{directory} \\! -type d -print0 | xargs -0 shasum -a 256")
      output.split("\n").map do |line|
        line.split(' ').first
      end
    end

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

      patches_path = File.join(RELEASE_ROOT, 'src', 'patches')
      @runner.run("cp -R #{patches_path} #{File.join(@working_dir)}")

      Dir.chdir(@working_dir) do
        packaging_script_path = File.join(RELEASE_ROOT, 'packages', 'nginx', 'packaging')
        @runner.run("bash #{packaging_script_path}", env: {
          'BOSH_INSTALL_TARGET' => @install_dir,
        })
      end
    end
  end
end
