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
    let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.legacy_manifest)) }
    let(:vm) do
      Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-007', deployment: deployment_model)
    end
    let(:test_problem_handler) { ProblemHandlers::Base.create_by_type(:test_problem_handler, vm.id, {}) }
    let(:fake_cloud) { instance_double('Bosh::Cloud') }
    let(:vm_deleter) { instance_double(Bosh::Director::VmDeleter) }
    before { allow(VmDeleter).to receive(:new).and_return(vm_deleter) }

    let(:vm_creator) { instance_double(Bosh::Director::VmCreator) }
    before { allow(VmCreator).to receive(:new).and_return(vm_creator) }

    before { allow(AgentClient).to receive(:with_vm).with(vm, anything).and_return(agent_client) }
    let(:agent_client) { instance_double(AgentClient) }

    def fake_job_context
      test_problem_handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
      allow(Config).to receive(:cloud).and_return(fake_cloud)
    end

    describe '#delete_vm' do
      before { fake_job_context }
      context 'when VM does not have disks' do
        before { allow(agent_client).to receive(:list_disk).and_return([]) }

        it 'deletes VM using vm_deleter' do
          expect(vm_deleter).to receive(:delete_vm).with(vm)
          test_problem_handler.delete_vm(vm)
        end
      end

      context 'when VM has disks' do
        before { allow(agent_client).to receive(:list_disk).and_return(['fake-disk-cid']) }

        it 'fails' do
          expect {
            test_problem_handler.delete_vm(vm)
          }.to raise_error 'VM has persistent disk attached'
        end
      end
    end

    describe '#recreate_vm' do
      let(:instance) { Models::Instance.make(deployment: deployment_model, job: 'mysql_node', index: 0, vm_id: vm.id) }
      before { vm.instance = instance }

      describe 'error handling' do
        it 'fails if VM does not an associated instance' do
          vm.instance = nil

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error 'VM does not have an associated instance'
        end

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
      end

      describe 'actually recreating the VM' do
        let(:spec) do
          {
            'vm_type' => {
              'name' => 'vm-type',
              'cloud_properties' => {'foo' => 'bar'},
            },
            'stemcell' => {
              'name' => 'stemcell-name',
              'version' => '3.0.2'
            },
            'networks' => ['A', 'B', 'C']
          }
        end
        let(:fake_new_agent) { double('Bosh::Director::AgentClient') }

        before do
          vm.update(apply_spec: spec, env: {'key1' => 'value1'})
          allow(AgentClient).to receive(:with_vm).with(vm, anything).and_return(fake_new_agent)
        end

        it 'recreates the VM' do
          fake_job_context

          expect(vm_deleter).to receive(:delete_for_instance_plan) do |instance_plan, options|
            expect(instance_plan.instance.network_settings).to eq(['A', 'B', 'C'])
            expect(instance_plan.instance.vm_type.cloud_properties).to eq({'foo' => 'bar'})
            expect(instance_plan.instance.env).to eq({'key1' => 'value1'})

            expect(options).to eq({skip_disks: true})
          end

          expect(vm_creator).to receive(:create_for_instance_plan) do |instance_plan|
            expect(instance_plan.instance.network_settings).to eq(['A', 'B', 'C'])
            expect(instance_plan.instance.vm_type.cloud_properties).to eq({'foo' => 'bar'})
            expect(instance_plan.instance.env).to eq({'key1' => 'value1'})

            vm
          end

          expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
          expect(fake_new_agent).to receive(:start).ordered

          test_problem_handler.apply_resolution(:recreate_vm)
        end
      end
    end
  end
end
