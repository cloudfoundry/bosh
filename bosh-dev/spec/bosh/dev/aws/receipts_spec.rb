require 'spec_helper'
require 'bosh/dev/aws/receipts'

module Bosh::Dev::Aws
  describe Receipts do
    subject { described_class.new(env) }
    let(:env) { { 'BOSH_VPC_SUBDOMAIN' => 'fake_BOSH_VPC_SUBDOMAIN' } }

    before { allow(Bosh::Dev::DeploymentsRepository).to receive(:new).and_return(deployments_repository) }
    let(:deployments_repository) do
      instance_double(
        'Bosh::Dev::DeploymentsRepository',
        clone_or_update!: true,
        path: '/fake/deployments/path',
      )
    end

    describe '#vpc_outfile_path' do
      its(:vpc_outfile_path) { should eq('/fake/deployments/path/fake_BOSH_VPC_SUBDOMAIN/aws_vpc_receipt.yml') }

      it 'clones or updates the aws deployments repository' do
        expect(deployments_repository).to receive(:clone_or_update!)
        subject.vpc_outfile_path
      end
    end

    describe '#route53_outfile_path' do
      its(:route53_outfile_path) { should eq('/fake/deployments/path/fake_BOSH_VPC_SUBDOMAIN/aws_route53_receipt.yml') }

      it 'clones or updates the aws deployments repository' do
        expect(deployments_repository).to receive(:clone_or_update!)
        subject.route53_outfile_path
      end
    end
  end
end
