require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteVm do
    subject(:job) { described_class.new(vm_cid) }
    before do
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(delete_vm_job)
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(event_log).to receive(:begin_stage).and_return(stage)
      allow(stage).to receive(:advance_and_track).and_yield

      allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud_factory).to receive(:uses_cpi_config?).and_return(false)
    end

    let(:vm_cid) { 'vm_cid' }
    let(:task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }
    let(:delete_vm_job) do
      instance_double(Bosh::Director::Jobs::DeleteVm, username: 'user', task_id: task.id, event_manager: event_manager)
    end
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:stage) { instance_double(Bosh::Director::EventLog::Stage) }

    shared_examples_for 'vm delete' do
      it 'should delete vm' do
        expect(cloud).to receive(:delete_vm).with(vm_cid)
        expect(event_log).to receive(:begin_stage).with('Delete VM', 1).and_return(stage)
        expect(stage).to receive(:advance_and_track).with('vm_cid')
        expect(job.perform).to eq 'vm vm_cid deleted'
      end

      it 'should not raise error' do
        expect(cloud).to receive(:delete_vm).with(vm_cid).and_raise(Bosh::Clouds::VMNotFound)
        expect(job.perform).to eq 'vm vm_cid deleted'
      end

      it 'should raise error' do
        expect(cloud).to receive(:delete_vm).with(vm_cid).and_raise(Exception)
        expect { job.perform }.to raise_error(Exception)
      end
    end

    describe 'perform' do
      describe 'DJ job class expectations' do
        let(:job_type) { :delete_vm }
        let(:queue) { :normal }
        it_behaves_like 'a DJ job'
      end

      context 'when instance has reference to vm' do
        before do
          allow(cloud_factory).to receive(:get).with('', nil).and_return(cloud)

          deployment = Bosh::Director::Models::Deployment.make(name: 'test_deployment')
          is = Bosh::Director::Models::Instance.make(
            deployment: deployment,
            job: 'foo-job',
            uuid: 'instance_id',
            index: 0,
            ignore: true,
          )
          vm = Bosh::Director::Models::Vm.make(cid: vm_cid, instance_id: is.id)
          is.active_vm = vm
          is.save
        end

        it_behaves_like 'vm delete'

        it 'should store event' do
          expect(cloud).to receive(:delete_vm).with(vm_cid)
          expect do
            job.perform
          end.to change { Bosh::Director::Models::Event.count }.by(2)

          event1 = Bosh::Director::Models::Event.order_by(:id).first
          expect(event1.user).to eq(task.username)
          expect(event1.action).to eq('delete')
          expect(event1.object_type).to eq('vm')
          expect(event1.object_name).to eq('vm_cid')
          expect(event1.instance).to eq('foo-job/instance_id')
          expect(event1.deployment).to eq('test_deployment')
          expect(event1.task).to eq(task.id.to_s)

          event2 = Bosh::Director::Models::Event.order_by(:id).last
          expect(event2.parent_id).to eq(event1.id)
          expect(event2.user).to eq(task.username)
          expect(event2.action).to eq('delete')
          expect(event2.object_type).to eq('vm')
          expect(event2.object_name).to eq('vm_cid')
          expect(event2.instance).to eq('foo-job/instance_id')
          expect(event2.deployment).to eq('test_deployment')
          expect(event2.task).to eq(task.id.to_s)
        end

        it 'should update instance' do
          expect(cloud).to receive(:delete_vm).with(vm_cid)
          job.perform
          expect(Bosh::Director::Models::Instance.all.first.vm_cid).to be_nil
        end
      end

      context 'when instance does not have reference to vm' do
        context 'it deletes and stores event' do
          before do
            expect(cloud_factory).to receive(:get).with(nil, 2).and_return(cloud)
          end

          it_behaves_like 'vm delete'

          it 'should store event' do
            expect(cloud).to receive(:delete_vm).with(vm_cid)
            job.perform
            event1 = Bosh::Director::Models::Event.order(:timestamp, :id).first
            expect(event1.user).to eq(task.username)
            expect(event1.action).to eq('delete')
            expect(event1.object_type).to eq('vm')
            expect(event1.object_name).to eq('vm_cid')
            expect(event1.instance).to be_nil
            expect(event1.deployment).to be_nil
            expect(event1.task).to eq(task.id.to_s)

            event2 = Bosh::Director::Models::Event.order(:timestamp, :id).last
            expect(event2.parent_id).to eq(event1.id)
            expect(event2.user).to eq(task.username)
            expect(event2.action).to eq('delete')
            expect(event2.object_type).to eq('vm')
            expect(event2.object_name).to eq('vm_cid')
            expect(event2.instance).to be_nil
            expect(event2.deployment).to be_nil
            expect(event2.task).to eq(task.id.to_s)
          end
        end
      end
    end
  end
end
