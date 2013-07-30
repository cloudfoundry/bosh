require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bat/bosh_cli'

module Bosh::Dev::Aws
  class MicroBoshDeploymentManifest
    def initialize
      @bosh_cli = Bosh::Dev::Bat::BoshCli.new
      @receipts = Receipts.new
    end

    def write
      bosh_cli.run_bosh "aws generate micro_bosh '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}'"
    end

    private

    attr_reader :bosh_cli, :receipts
  end
end
