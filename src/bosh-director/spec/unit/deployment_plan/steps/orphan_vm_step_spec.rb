require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe OrphanVmStep do
        subject(:step) { described_class.new(vm) }

        let(:deployment) { Models::Deployment.make(name: 'fake-name-1') }
        let(:instance) { Models::Instance.make(deployment: deployment, job: 'fake-job-1', uuid: 'fake-uuid-1') }
        let!(:vm) do
          Models::Vm.make(
            instance: instance,
            active: false,
            cpi: 'vm-cpi',
            stemcell_api_version: 9876,
            cid: 'fake-vm-cid-1',
            agent_id: 'fake-agent-id',
          )
        end
        let!(:ip_address) { Models::IpAddress.make(instance: instance, vm: vm) }
        let(:report) { double(:report) }
        let(:job) { instance_double(Bosh::Director::Jobs::BaseJob, username: 'fake-username', task_id: 'fake-task-id') }
        let!(:event_manager) { Api::EventManager.new(true) }
        let(:agent) { instance_double(AgentClient) }

        before do
          allow(job).to receive(:event_manager).and_return(event_manager)
          allow(Config).to receive(:current_job).and_return(job)
          allow(AgentClient).to receive(:with_agent_id).with('fake-agent-id', 'fake-job-1/fake-uuid-1').and_return(agent)
          allow(agent).to receive(:shutdown)
        end

        it 'removes the vm record' do
          expect do
            step.perform(report)
          end.to change { Models::Vm.count }.by(-1)

          expect do
            vm.reload
          end.to raise_error(/Record not found/)
        end

        it 'removes the ip address from the instance' do
          expect(ip_address.instance).not_to be_nil
          step.perform(report)
          ip_address.reload
          expect(ip_address.instance).to be_nil
        end

        it 'creates an orphaned vm record' do
          expect do
            step.perform(report)
          end.to change { Models::OrphanedVm.count }.by(1)

          orphaned_vm = Models::OrphanedVm.last
          expect(orphaned_vm.availability_zone).to eq instance.availability_zone
          expect(orphaned_vm.cid).to eq vm.cid
          expect(orphaned_vm.cloud_properties).to eq instance.cloud_properties
          expect(orphaned_vm.cpi).to eq vm.cpi
          expect(orphaned_vm.stemcell_api_version).to eq(9876)
          expect(orphaned_vm.orphaned_at).to be_a Time
          expect(orphaned_vm.deployment_name).to eq(instance.deployment.name)
          expect(orphaned_vm.instance_name).to eq(instance.name)
        end

        it 'moves ips over to the orphaned vm' do
          ip1 = Models::IpAddress.make(vm: vm, address_str: '1.1.1.1')
          ip2 = Models::IpAddress.make(vm: vm, address_str: '2.2.2.2')
          expect(vm.ip_addresses.count).to eq 3
          step.perform(report)
          orphaned_vm = Models::OrphanedVm.last
          expect(orphaned_vm.ip_addresses.count).to eq 3
          expect(orphaned_vm.ip_addresses).to contain_exactly(ip_address, ip1, ip2)
          expect(ip_address.reload.orphaned_vm_id).to equal(orphaned_vm.id)
          expect(ip_address.reload.vm_id).to equal(nil)
          expect(ip1.reload.orphaned_vm_id).to equal(orphaned_vm.id)
          expect(ip1.reload.vm_id).to equal(nil)
          expect(ip2.reload.orphaned_vm_id).to equal(orphaned_vm.id)
          expect(ip2.reload.vm_id).to equal(nil)
        end

        it 'sends a shutdown to the agent' do
          expect(agent).to receive(:shutdown)
          step.perform(report)
        end

        let(:base_orphan_vm_event) do
          {
            user: 'fake-username',
            action: 'orphan',
            object_type: 'vm',
            object_name: 'fake-vm-cid-1',
            task: 'fake-task-id',
            deployment: 'fake-name-1',
            instance: 'fake-job-1/fake-uuid-1',
          }
        end

        it 'stores events' do
          expect(event_manager).to receive(:create_event).with(base_orphan_vm_event.merge(
            parent_id: nil,
            error: nil,
          )).and_return(instance_double(Models::Event, id: 123))

          expect(event_manager).to receive(:create_event).with(base_orphan_vm_event.merge(
            parent_id: 123,
            error: nil,
          )).and_return(instance_double(Models::Event, id: 456))

          step.perform(report)
        end

        context 'errors during orphaning' do
          let(:error) { RuntimeError.new('a fake error') }

          before do
            allow(vm).to receive(:destroy).and_raise error
          end

          it 'stores events with errors if they occur' do
            expect(event_manager).to receive(:create_event).with(base_orphan_vm_event.merge(
              parent_id: nil,
              error: nil,
            )).and_return(instance_double(Models::Event, id: 123))

            expect(event_manager).to receive(:create_event).with(base_orphan_vm_event.merge(
              parent_id: 123,
              error: error,
            )).and_return(instance_double(Models::Event, id: 456))

            expect { step.perform(report) }.to raise_error(error)
          end
        end
      end
    end
  end
end
