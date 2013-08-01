require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bat/bosh_cli_session'

module Bosh::Dev::Aws
  class BatDeploymentManifest
    def initialize(bosh_cli_session, stemcell_version)
      @bosh_cli_session = bosh_cli_session
      @stemcell_version = stemcell_version
      @receipts = Receipts.new
    end

    def write
      bosh_cli_session.run_bosh "aws generate bat '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}' '#{stemcell_version}'"
    end

    private

    attr_reader :bosh_cli_session, :receipts, :stemcell_version
  end
end
