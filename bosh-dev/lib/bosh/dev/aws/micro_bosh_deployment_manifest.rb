require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Aws
  class MicroBoshDeploymentManifest
    def initialize(env, bosh_cli_session)
      @bosh_cli_session = bosh_cli_session
      @receipts = Receipts.new(env)
    end

    def write
      bosh_cli_session.run_bosh "aws generate micro_bosh '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}'"
    end

    private

    attr_reader :bosh_cli_session, :receipts
  end
end
