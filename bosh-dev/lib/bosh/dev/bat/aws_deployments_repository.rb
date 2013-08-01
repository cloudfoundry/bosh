require 'fileutils'
require 'bosh/dev/bat'
require 'bosh/dev/bat/shell'

module Bosh::Dev::Bat
  class AwsDeploymentsRepository
    def initialize
      @env = ENV.to_hash
      @shell = Shell.new
    end

    def path
      File.join(path_root, 'deployments')
    end

    def clone_or_update!
      Dir.exists?(path) ? update_repo : clone_repo
    end

    private

    attr_reader :env, :shell

    def path_root
      env.fetch('FAKE_MNT', '/mnt')
    end

    def update_repo
      Dir.chdir(path) { shell.run('git pull') }
    end

    def clone_repo
      FileUtils.mkdir_p(path, verbose: true)
      shell.run("git clone #{env.fetch('BOSH_JENKINS_DEPLOYMENTS_REPO')} #{path}")
    end
  end
end
