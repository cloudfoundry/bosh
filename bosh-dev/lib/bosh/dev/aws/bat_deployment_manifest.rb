require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Aws
  class BatDeploymentManifest
    def initialize(env, bosh_cli_session, stemcell_archive)
      @bosh_cli_session = bosh_cli_session
      @stemcell_archive = stemcell_archive
      @receipts = Receipts.new(env)
    end

    def write
      bosh_cli_session.run_bosh "aws generate bat '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}' '#{stemcell_archive.version}' '#{stemcell_archive.name}'"
    end

    private

    attr_reader :bosh_cli_session, :receipts, :stemcell_archive
  end
end
