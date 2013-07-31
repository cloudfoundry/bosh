require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bat/bosh_cli_session'

module Bosh::Dev::Aws
  class BatDeploymentManifest
    def initialize(bosh_cli_session, stemcell_archive)
      @bosh_cli_session = bosh_cli_session
      @stemcell_archive = stemcell_archive
      @receipts = Receipts.new
    end

    def write
      bosh_cli_session.run_bosh "aws generate bat '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}' '#{stemcell_archive.version}'"
    end

    private

    attr_reader :bosh_cli_session, :receipts, :stemcell_archive
  end
end
