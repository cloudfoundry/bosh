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

    describe '#add_event' do
      before do
        allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40Z'))
      end
      let (:options) do
        {:event_state  => 'started',
         :event_result => 'running',
         :task_id      => 42}
      end

      it 'should store new event' do
        expect {
          job.add_event(options)
        }.to change {
          Bosh::Director::Models::Event.count }.from(0).to(1)

        event= Bosh::Director::Models::Event.first
        expect(event.event_state).to eq('started')
        expect(event.target_type).to eq('deployment')
        expect(event.target_name).to eq('test_deployment')
        expect(event.event_action).to eq('delete')
        expect(event.event_result).to eq('running')
        expect(event.task_id).to eq(42)
        expect(event.timestamp).to eq(Time.now)
      end
    end
  end
end
