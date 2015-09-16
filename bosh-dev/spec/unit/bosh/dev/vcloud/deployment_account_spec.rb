require 'spec_helper'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/vcloud/deployment_account'

module Bosh::Dev::VCloud
  describe DeploymentAccount do
    subject(:account) do
      described_class.new(
        'fake-env',
        'fake-deployment-name',
        deployments_repository,
      )
    end

    let(:deployments_repository) do
      instance_double(
        'Bosh::Dev::DeploymentsRepository',
        path: '/tmp/deployments-repo',
        clone_or_update!: nil,
      )
    end

    its(:bosh_user)     { should eq 'admin' }
    its(:bosh_password) { should eq 'admin' }

    describe '#manifest_path' do
      it 'clones or updates repository' do
        expect(deployments_repository).to receive(:clone_or_update!).with(no_args)
        subject.manifest_path
      end

      it 'does not clone or update repository during second call' do
        expect(deployments_repository).to receive(:clone_or_update!).once
        subject.manifest_path
        subject.manifest_path
      end

      it 'returns deployment manifest path' do
        expect(subject.manifest_path).to eq(
          '/tmp/deployments-repo/fake-env/fake-deployment-name/manifest.yml')
      end
    end

    describe '#prepare' do
      it('does nothing') { subject.prepare }
    end

    describe '#save' do
      it 'pushes changes to deployments repo' do
        expect(deployments_repository).to receive(:update_and_push)
        account.save
      end
    end
  end
end
