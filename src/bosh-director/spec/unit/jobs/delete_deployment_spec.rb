require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeployment do
    include Support::FakeLocks
    before { fake_locks }

    subject(:job) { described_class.new('test_deployment', job_options) }
    let(:job_options) do
      {}
    end
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

    before do
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40+00:00'))
      allow(Config).to receive(:event_log).and_return(event_log)
    end

    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    describe 'DJ job class expectations' do
      let(:job_type) { :delete_deployment }
      let(:queue) { :normal }

      it_behaves_like 'a DelayedJob job'
    end

    it 'should fail if the deployment is not found' do
      expect { job.perform }.to raise_exception DeploymentNotFound
    end

    it 'fails when ignored instances exist in the to-be-deleted deployment' do
      deployment = FactoryBot.create(:models_deployment, name: 'test_deployment')
      FactoryBot.create(:models_instance, deployment: deployment, job: 'foo-job', index: 0, ignore: true)
      expect do
        job.perform
      end.to raise_exception DeploymentIgnoredInstancesDeletion, "You are trying to delete deployment 'test_deployment', " \
          'which contains ignored instance(s). Operation not allowed.'
    end

    it 'should store new events' do
      FactoryBot.create(:models_deployment, name: 'test_deployment')
      expect do
        job.perform
      end.to change { Bosh::Director::Models::Event.count }.from(0).to(2)

      event1 = Bosh::Director::Models::Event.order(:id).first
      expect(event1.user).to eq(task.username)
      expect(event1.action).to eq('delete')
      expect(event1.object_type).to eq('deployment')
      expect(event1.object_name).to eq('test_deployment')
      expect(event1.deployment).to eq('test_deployment')
      expect(event1.task).to eq(task.id.to_s)
      expect(event1.timestamp).to eq(Time.now)

      event2 = Bosh::Director::Models::Event.order(:id).last
      expect(event2.parent_id).to eq(event1.id)
      expect(event2.user).to eq(task.username)
      expect(event2.action).to eq('delete')
      expect(event2.object_type).to eq('deployment')
      expect(event2.object_name).to eq('test_deployment')
      expect(event2.deployment).to eq('test_deployment')
      expect(event2.task).to eq(task.id.to_s)
      expect(event2.timestamp).to eq(Time.now)
    end
  end
end
