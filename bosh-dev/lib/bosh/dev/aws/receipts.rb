require 'bosh/dev/aws'

module Bosh::Dev::Aws
  class Receipts
    def initialize
      @env = ENV.to_hash
      @mnt = env.fetch('FAKE_MNT', '/mnt')
    end

    def vpc_outfile_path
      path('aws_vpc_receipt.yml')
    end

    def route53_outfile_path
      path('aws_route53_receipt.yml')
    end

    private

    attr_reader :mnt, :env

    def path(filename)
      File.join(mnt, 'deployments', env.fetch('BOSH_VPC_SUBDOMAIN'), filename)
    end
  end
end
