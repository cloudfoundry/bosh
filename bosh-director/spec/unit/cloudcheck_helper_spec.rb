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
      Config.stub(cloud: fake_cloud)
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
          VmCreator.stub(:generate_agent_id).and_return('agent-222')
          Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')

          vm.update(apply_spec: spec, env: {'key1' => 'value1'})

          SecureRandom.stub(:uuid).and_return('agent-222')
          AgentClient.stub(:with_defaults).with('agent-222', anything).and_return(fake_new_agent)
        end

        context 'when there is a persistent disk' do
          before do
            Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
          end

          context 'and the disk is attached' do

            it 'recreates VM (w/persistent disk)' do
              fake_cloud.should_receive(:delete_vm).with('vm-cid').ordered
              fake_cloud.should_receive(:create_vm).
                  with('agent-222', 'sc-302', {'foo' => 'bar'}, ['A', 'B', 'C'], ['disk-cid'], {'key1' => 'value1'}).
                  ordered.and_return('new-vm-cid')

              vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
              Bosh::Director::VmMetadataUpdater.stub(build: vm_metadata_updater)
              vm_metadata_updater.should_receive(:update) do |vm, metadata|
                expect(vm.cid).to eq('new-vm-cid')
                expect(metadata).to eq({})
              end

              fake_new_agent.should_receive(:wait_until_ready).ordered
              fake_cloud.should_receive(:attach_disk).with('new-vm-cid', 'disk-cid').ordered

              fake_new_agent.should_receive(:mount_disk).with('disk-cid').ordered
              fake_new_agent.should_receive(:apply).with(spec).ordered
              fake_new_agent.should_receive(:start).ordered

              fake_job_context

              expect {
                test_problem_handler.apply_resolution(:recreate_vm)
              }.to change { Models::Vm.where(agent_id: 'agent-007').count }.from(1).to(0)

              instance.reload
              instance.vm.apply_spec.should == spec
              instance.vm.cid.should == 'new-vm-cid'
              instance.vm.agent_id.should == 'agent-222'
              instance.persistent_disk.disk_cid.should == 'disk-cid'
            end
          end
        end

        context 'when there is no persistent disk' do
          it 'just recreates the VM' do
            fake_cloud.should_receive(:delete_vm).with('vm-cid').ordered
            fake_cloud.should_receive(:create_vm).
                with('agent-222', 'sc-302', {'foo' => 'bar'}, ['A', 'B', 'C'], [], {'key1' => 'value1'}).
                ordered.and_return('new-vm-cid')

            vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
            Bosh::Director::VmMetadataUpdater.stub(build: vm_metadata_updater)
            vm_metadata_updater.should_receive(:update) do |vm, metadata|
              expect(vm.cid).to eq('new-vm-cid')
              expect(metadata).to eq({})
            end

            fake_new_agent.should_receive(:wait_until_ready).ordered
            fake_new_agent.should_receive(:apply).with(spec).ordered
            fake_new_agent.should_receive(:start).ordered

            fake_job_context

            expect {
              test_problem_handler.apply_resolution(:recreate_vm)
            }.to change { Models::Vm.where(agent_id: 'agent-007').count }.from(1).to(0)

            instance.reload
            instance.vm.apply_spec.should == spec
            instance.vm.cid.should == 'new-vm-cid'
            instance.vm.agent_id.should == 'agent-222'
          end
        end
      end
    end
  end
end
