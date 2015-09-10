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
      bosh_base = File.expand_path('../../../../../..', __FILE__)
      ruby_spec = YAML.load_file(File.join(bosh_base, 'release/packages/ruby/spec'))
      ruby_spec['files'].find { |f| f =~ /ruby-(.*).tar.gz/ }
      release_ruby = $1
      runner_ruby = ENV['CLI_RUBY_VERSION'] || release_ruby

      Dir.chdir(RELEASE_ROOT) do
        if has_chruby?
          @runner.run "chruby-exec #{runner_ruby} -- bundle exec bosh sync blobs"
        else
          @runner.run "bundle exec bosh sync blobs"
        end
      end

      # Dir.chdir(RELEASE_ROOT) { @runner.run('bundle exec bosh sync blobs') }
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(@working_dir)
      FileUtils.rm_rf(@install_dir)

      FileUtils.mkdir_p(@working_dir)
      FileUtils.mkdir_p(@install_dir)

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

    private

    def has_chruby?
      out, status = Open3.capture2e('chruby-exec --help')
      status.success?
    rescue
        false
    end
  end
end
