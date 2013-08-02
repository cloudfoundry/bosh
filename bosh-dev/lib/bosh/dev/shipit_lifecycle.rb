require 'rugged'

require 'bosh/dev/shell'

module Bosh::Dev
  class ShipitLifecycle

    def initialize
      @shell = Bosh::Dev::Shell.new
    end

    def pull
      @shell.run("git pull --rebase origin #{current_branch}")
    end

    def push
      @shell.run("git push origin #{current_branch}")
    end

    private

    def current_branch
      current_repo_path = Rugged::Repository.discover('.')
      current_repo = Rugged::Repository.new(current_repo_path)
      current_repo.head.name.split('/').last
    end
  end
end