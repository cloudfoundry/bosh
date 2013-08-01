require 'spec_helper'
require 'bosh/dev/aws/receipts'

module Bosh::Dev::Aws
  describe Receipts do
    let(:aws_deployments_repository) do
      instance_double('Bosh::Dev::Aws::DeploymentsRepository',
                      clone_or_update!: true,
                      path: '/fake/deployments/path')
    end

    before do
      DeploymentsRepository.stub(new: aws_deployments_repository)

      ENV.stub(to_hash: {
        'BOSH_VPC_SUBDOMAIN' => 'fake_BOSH_VPC_SUBDOMAIN',
      })
    end

    describe '#vpc_outfile_path' do
      its(:vpc_outfile_path) { should eq('/fake/deployments/path/fake_BOSH_VPC_SUBDOMAIN/aws_vpc_receipt.yml') }

      it 'clones or updates the aws deployments repository' do
        aws_deployments_repository.should_receive(:clone_or_update!)

        subject.vpc_outfile_path
      end
    end

    describe '#route53_outfile_path' do
      its(:route53_outfile_path) { should eq('/fake/deployments/path/fake_BOSH_VPC_SUBDOMAIN/aws_route53_receipt.yml') }

      it 'clones or updates the aws deployments repository' do
        aws_deployments_repository.should_receive(:clone_or_update!)

        subject.route53_outfile_path
      end
    end
  end
end
