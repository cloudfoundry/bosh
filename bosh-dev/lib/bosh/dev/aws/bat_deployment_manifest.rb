require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bat/bosh_cli'

module Bosh::Dev::Aws
  class BatDeploymentManifest
    def initialize(stemcell_archive)
      @bosh_cli = Bosh::Dev::Bat::BoshCli.new
      @receipts = Receipts.new
      @stemcell_archive = stemcell_archive
    end

    def write
      bosh_cli.run_bosh "aws generate bat '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}' '#{stemcell_archive.version}'"
    end

    private

    attr_reader :bosh_cli, :receipts, :stemcell_archive
  end
end
