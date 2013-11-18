require 'fileutils'
require 'bosh/dev'
require 'bosh/core/shell'
require 'bosh/dev/git_repo_updater'

module Bosh::Dev
  class DeploymentsRepository
    def initialize(env, options = {})
      @env = env
      @shell = Bosh::Core::Shell.new
      @path_root = options.fetch(:path_root) { env.fetch('FAKE_MNT', '/mnt') }
    end

    def path
      File.join(path_root, 'deployments')
    end

    def clone_or_update!
      git_repo?(path) ? update_repo : clone_repo
    end

    def push
      git_repo_updater = Bosh::Dev::GitRepoUpdater.new
      git_repo_updater.update_directory(path)
    end

    private

    attr_reader :env, :shell, :path_root

    def update_repo
      Dir.chdir(path) { shell.run('git pull') }
    end

    def clone_repo
      FileUtils.mkdir_p(path, verbose: true)
      shell.run("git clone #{env.fetch('BOSH_JENKINS_DEPLOYMENTS_REPO')} #{path}")
    end

    def git_repo?(path)
      Dir.exists?(File.join(path, '.git'))
    end
  end
end
