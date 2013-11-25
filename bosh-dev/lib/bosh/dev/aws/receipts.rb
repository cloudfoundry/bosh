require 'bosh/dev/aws'
require 'bosh/dev/deployments_repository'

module Bosh::Dev::Aws
  class Receipts
    def initialize(env)
      @env = env
      @deployments_repository = Bosh::Dev::DeploymentsRepository.new(env)
    end

    def vpc_outfile_path
      path('aws_vpc_receipt.yml')
    end

    def route53_outfile_path
      path('aws_route53_receipt.yml')
    end

    private

    attr_reader :env, :deployments_repository

    def path(filename)
      ensure_repository_exists

      File.join(deployments_repository.path, env.fetch('BOSH_VPC_SUBDOMAIN'), filename)
    end

    def ensure_repository_exists
      deployments_repository.clone_or_update!
    end
  end
end
