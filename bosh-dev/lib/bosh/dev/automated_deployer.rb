require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class AutomatedDeployer
    def initialize(options = {})
      @target = options.fetch(:target)
      @username = options.fetch(:username)
      @password = options.fetch(:password)

      @cli = options.fetch(:cli) { BoshCliSession.new }
    end

    def deploy(options = {})
      manifest_path = options.fetch(:manifest_path)
      release_path = options.fetch(:release_path)
      stemcell_path = options.fetch(:stemcell_path)

      cli.run_bosh("target #{target}")
      cli.run_bosh("login #{username} #{password}")
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh("upload stemcell #{stemcell_path}", debug_on_fail: true)
      cli.run_bosh("upload release #{release_path}", debug_on_fail: true)
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    private

    attr_reader :target, :username, :password, :cli

  end
end