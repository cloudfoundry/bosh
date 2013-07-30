require 'bosh/dev/aws'

module Bosh::Dev::Aws
  class Receipts
    def initialize
      @mnt = ENV.fetch('FAKE_MNT', '/mnt')
    end

    def vpc_outfile_path
      File.join(mnt, 'deployments', ENV.to_hash.fetch('BOSH_VPC_SUBDOMAIN'), 'aws_vpc_receipt.yml')
    end

    def route53_outfile_path
      File.join(mnt, 'deployments', ENV.to_hash.fetch('BOSH_VPC_SUBDOMAIN'), 'aws_route53_receipt.yml')
    end

    private

    attr_reader :mnt
  end
end