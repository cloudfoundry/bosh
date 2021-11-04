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
      retrieve_nginx_package
      if !File.file?(File.join(@install_dir, 'sbin', 'nginx')) || blob_has_changed || platform_has_changed
        compile
      else
        puts 'Skipping compiling nginx because shasums and platform have not changed'
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

    def platform_has_changed
      output = @runner.run("cat #{@install_dir}/platform || true")
      output != RUBY_PLATFORM
    end

    def shasum(directory)
      output = @runner.run("find #{directory} \\! -type d -print0 | xargs -0 shasum -a 256")
      output.split("\n").map do |line|
        line.split(' ').first
      end
    end

    def sync_release_blobs
      Dir.chdir(RELEASE_ROOT) { @runner.run('bosh sync-blobs') }
    end

    def retrieve_nginx_package
      Dir.chdir(RELEASE_ROOT) do
        @runner.run('bosh create-release --force --tarball /tmp/release.tgz')
        @runner.run('tar -zxvf /tmp/release.tgz -C /tmp packages/nginx.tgz')
        @runner.run('tar -xvf /tmp/packages/nginx.tgz  -C packages/nginx')
      end
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(@working_dir)
      FileUtils.rm_rf(@install_dir)

      FileUtils.mkdir_p(@working_dir)
      FileUtils.mkdir_p(@install_dir)

      if /darwin/ =~ RUBY_PLATFORM
        # search homebrew paths for openssl on osx (fixes nginx compilation issues)
        ENV['LDFLAGS'] = '-L/usr/local/opt/openssl/lib'
        ENV['CPPFLAGS'] = '-I/usr/local/opt/openssl/include'
      end
      @runner.run("echo '#{RUBY_PLATFORM}' > #{@install_dir}/platform")

      # Make sure packaging script has its own blob copies so that blobs/ directory is not affected
      nginx_blobs_path = File.join(RELEASE_ROOT, 'packages', 'nginx')
      @runner.run("cp -R #{nginx_blobs_path}/. #{File.join(@working_dir)}")

      Dir.chdir(@working_dir) do
        packaging_script_path = File.join(RELEASE_ROOT, 'packages', 'nginx', 'packaging')
        @runner.run("bash #{packaging_script_path}", env: {
          'BOSH_INSTALL_TARGET' => @install_dir,
        })
      end
    end
  end
end
