require 'bosh/dev/aws'
require 'bosh/dev/aws/receipts'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Aws
  class BatDeploymentManifest

    attr_reader :net_type

    def initialize(env, net_type, bosh_cli_session, stemcell_archive)
      @receipts = Receipts.new(env)
      @net_type = net_type
      @bosh_cli_session = bosh_cli_session
      @stemcell_archive = stemcell_archive
    end

    def write
      bosh_cli_session.run_bosh "aws generate bat '#{receipts.vpc_outfile_path}' '#{receipts.route53_outfile_path}' '#{stemcell_archive.version}' '#{stemcell_archive.name}'"

      net_type = YAML.load_file('bat.yml')['properties']['networks'][0]['type']
      unless net_type == @net_type
        raise "Specified '#{@net_type}' networking but environment requires '#{net_type}'"
      end
    end

    private

    attr_reader :bosh_cli_session, :receipts, :stemcell_archive
  end
end
