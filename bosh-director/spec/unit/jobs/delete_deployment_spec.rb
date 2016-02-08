require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeployment do
    include Support::FakeLocks
    before { fake_locks }

    subject(:job) { described_class.new('test_deployment', job_options) }
    let(:job_options) { {} }
    before do
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
    end

    let(:cloud) { instance_double('Bosh::Cloud') }

    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    describe 'Resque job class expectations' do
      let(:job_type) { :delete_deployment }
      it_behaves_like 'a Resque job'
    end

    it 'should fail if the deployment is not found' do
      expect { job.perform }.to raise_exception DeploymentNotFound
    end
  end
end
