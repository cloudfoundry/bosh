require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeployment do
    include Support::FakeLocks
    before { fake_locks }

    subject(:job) { described_class.new('test_deployment', job_options) }
    let(:job_options) { {} }
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    before do
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40+00:00'))
    end

    let(:cloud) { instance_double('Bosh::Cloud') }

    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    describe 'DJ job class expectations' do
      let(:job_type) { :delete_deployment }
      it_behaves_like 'a DJ job'
    end

    it 'should fail if the deployment is not found' do
      expect { job.perform }.to raise_exception DeploymentNotFound
    end

    it 'should store new events' do
      Bosh::Director::Models::Deployment.make(name: 'test_deployment')
      expect {
        job.perform
      }.to change {
        Bosh::Director::Models::Event.count }.from(0).to(2)

      event_1 = Bosh::Director::Models::Event.first
      expect(event_1.user).to eq(task.username)
      expect(event_1.action).to eq('delete')
      expect(event_1.object_type).to eq('deployment')
      expect(event_1.object_name).to eq('test_deployment')
      expect(event_1.deployment).to eq('test_deployment')
      expect(event_1.task).to eq("#{task.id}")
      expect(event_1.timestamp).to eq(Time.now)

      event_2 = Bosh::Director::Models::Event.order(:id).last
      expect(event_2.parent_id).to eq(1)
      expect(event_2.user).to eq(task.username)
      expect(event_2.action).to eq('delete')
      expect(event_2.object_type).to eq('deployment')
      expect(event_2.object_name).to eq('test_deployment')
      expect(event_2.deployment).to eq('test_deployment')
      expect(event_2.task).to eq("#{task.id}")
      expect(event_2.timestamp).to eq(Time.now)
    end
  end
end
