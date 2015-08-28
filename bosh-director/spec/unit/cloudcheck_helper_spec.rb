# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe CloudcheckHelper do
    class TestProblemHandler < ProblemHandlers::Base
      register_as :test_problem_handler

      def initialize(vm_id, data)
        super
        @vm = Models::Vm[vm_id]
      end

      resolution :recreate_vm do
        action { recreate_vm(@vm) }
      end
    end

    let(:vm) { Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-007') }
    let(:test_problem_handler) { ProblemHandlers::Base.create_by_type(:test_problem_handler, vm.id, {}) }
    let(:fake_cloud) { instance_double('Bosh::Cloud') }

    def fake_job_context
      test_problem_handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
      allow(Config).to receive(:cloud).and_return(fake_cloud)
    end

    describe '#recreate_vm' do
      describe 'error handling' do
        it "doesn't recreate VM if apply spec is unknown" do
          vm.update(env: {})

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Unable to look up VM apply spec')
        end

        it "doesn't recreate VM if environment is unknown" do
          vm.update(apply_spec: {})

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Unable to look up VM environment')
        end

        it 'whines on invalid spec format' do
          vm.update(apply_spec: :foo, env: {})

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Invalid apply spec format')
        end

        it 'whines on invalid env format' do
          vm.update(apply_spec: {}, env: :bar)

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Invalid VM environment format')
        end

        it 'whines when stemcell is not in apply spec' do
          spec = {'resource_pool' => {'stemcell' => {'name' => 'foo'}}} # no version
          env = {'key1' => 'value1'}

          vm.update(apply_spec: spec, env: env)

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Unknown stemcell name and/or version')
        end

        it 'whines when stemcell is not in DB' do
          vm.update(apply_spec: {
            'resource_pool' => {
              'stemcell' => {
                'name' => 'stemcell-name',
                'version' => '3.0.2'
              }
            }
          }, env: {'key1' => 'value1'})

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, "Unable to find stemcell 'stemcell-name 3.0.2'")
        end
      end

      describe 'actually recreating the VM' do
        let(:spec) do
          {
              'resource_pool' => {
                  'stemcell' => {
                      'name' => 'stemcell-name',
                      'version' => '3.0.2'
                  },
                  'cloud_properties' => {'foo' => 'bar'},
              },
              'networks' => ['A', 'B', 'C']
          }
        end
        let!(:instance) { Models::Instance.make(job: 'mysql_node', index: 0, vm_id: vm.id) }
        let(:fake_new_agent) { double('Bosh::Director::AgentClient') }

        before do
          allow(VmCreator).to receive(:generate_agent_id).and_return('agent-222')
          Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')

          vm.update(apply_spec: spec, env: {'key1' => 'value1'})

          allow(SecureRandom).to receive(:uuid).and_return('agent-222')
          allow(AgentClient).to receive(:with_defaults).with('agent-222', anything).and_return(fake_new_agent)
        end

        context 'when there is a persistent disk' do
          before do
            Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
            Bosh::Director::Config.trusted_certs=DIRECTOR_TEST_CERTS
          end

          def it_creates_vm_with_persistent_disk
            expect(fake_cloud).to receive(:delete_vm).with('vm-cid').ordered
            expect(fake_cloud).to receive(:create_vm).
              with('agent-222', 'sc-302', {'foo' => 'bar'}, ['A', 'B', 'C'], ['disk-cid'], {'key1' => 'value1'}).
              ordered.and_return('new-vm-cid')

            vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
            allow(Bosh::Director::VmMetadataUpdater).to receive(:build).and_return(vm_metadata_updater)
            expect(vm_metadata_updater).to receive(:update) do |vm, metadata|
              expect(vm.cid).to eq('new-vm-cid')
              expect(metadata).to eq({})
            end

            expect(fake_new_agent).to receive(:wait_until_ready).ordered
            expect(fake_new_agent).to receive(:update_settings).with(DIRECTOR_TEST_CERTS).ordered
            expect(fake_cloud).to receive(:attach_disk).with('new-vm-cid', 'disk-cid').ordered

            expect(fake_new_agent).to receive(:mount_disk).with('disk-cid').ordered
            expect(fake_new_agent).to receive(:apply).with(spec).ordered
            expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
            expect(fake_new_agent).to receive(:start).ordered

            fake_job_context

            expect {
              test_problem_handler.apply_resolution(:recreate_vm)
            }.to change { Models::Vm.where(agent_id: 'agent-007').count }.from(1).to(0)

            instance.reload
            expect(instance.vm.apply_spec).to eq(spec)
            expect(instance.vm.cid).to eq('new-vm-cid')
            expect(instance.vm.trusted_certs_sha1).to eq(DIRECTOR_TEST_CERTS_SHA1)
            expect(instance.vm.agent_id).to eq('agent-222')
            expect(instance.persistent_disk.disk_cid).to eq('disk-cid')
          end

          context 'and the disk is attached' do
            it 'recreates VM (w/persistent disk) after detaching the disk from the old vm' do
              it_creates_vm_with_persistent_disk
            end
          end

          context 'and the disk is already detached' do
            before do
              allow(fake_cloud).to receive(:detach_disk).and_raise(Bosh::Clouds::DiskNotAttached.new(false), 'fake-value')
            end

            it 'still recreates VM (w/persistent disk)' do
              it_creates_vm_with_persistent_disk
            end
          end
        end

        context 'when there is no persistent disk' do
          it 'just recreates the VM' do
            expect(fake_cloud).to receive(:delete_vm).with('vm-cid').ordered
            expect(fake_cloud).to receive(:create_vm).
                with('agent-222', 'sc-302', {'foo' => 'bar'}, ['A', 'B', 'C'], [], {'key1' => 'value1'}).
                ordered.and_return('new-vm-cid')

            vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
            allow(Bosh::Director::VmMetadataUpdater).to receive_messages(build: vm_metadata_updater)
            expect(vm_metadata_updater).to receive(:update) do |vm, metadata|
              expect(vm.cid).to eq('new-vm-cid')
              expect(metadata).to eq({})
            end

            expect(fake_new_agent).to receive(:wait_until_ready).ordered
            expect(fake_new_agent).to receive(:update_settings).ordered
            expect(fake_new_agent).to receive(:apply).with(spec).ordered
            expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
            expect(fake_new_agent).to receive(:start).ordered

            fake_job_context

            expect {
              test_problem_handler.apply_resolution(:recreate_vm)
            }.to change { Models::Vm.where(agent_id: 'agent-007').count }.from(1).to(0)

            instance.reload
            expect(instance.vm.apply_spec).to eq(spec)
            expect(instance.vm.cid).to eq('new-vm-cid')
            expect(instance.vm.agent_id).to eq('agent-222')
          end
        end

        context 'trusted certificate handling' do
          before do
            Bosh::Director::Config.trusted_certs=DIRECTOR_TEST_CERTS
            allow(fake_new_agent).to receive(:wait_until_ready)
            allow(fake_new_agent).to receive(:update_settings)
            allow(fake_new_agent).to receive(:apply)
            allow(fake_new_agent).to receive(:run_script).with('pre-start', {})
            allow(fake_new_agent).to receive(:start)

            fake_job_context

            allow(fake_cloud).to receive(:delete_vm).with('vm-cid').ordered
            allow(fake_cloud).to receive(:create_vm).
                                     with('agent-222', 'sc-302', {'foo' => 'bar'}, ['A', 'B', 'C'], [], {'key1' => 'value1'}).
                                     ordered.and_return('new-vm-cid')
          end

          it 'should update the database with the new VM''s trusted certs' do
            test_problem_handler.apply_resolution(:recreate_vm)
            expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1, agent_id: 'agent-222').count).to eq(1)
          end

          it 'should not update the DB with the new certificates when the new vm fails to start' do
            expect(fake_new_agent).to receive(:wait_until_ready).and_raise(RpcTimeout)

            begin
              test_problem_handler.apply_resolution(:recreate_vm)
            rescue RpcTimeout
              # expected
            end

            expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
          end

          it 'should not update the DB with the new certificates when the update_settings method fails' do
            expect(fake_new_agent).to receive(:update_settings).and_raise(RpcTimeout)

            begin
              test_problem_handler.apply_resolution(:recreate_vm)
            rescue RpcTimeout
              # expected
            end

            expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
          end
        end
      end
    end
  end
end
