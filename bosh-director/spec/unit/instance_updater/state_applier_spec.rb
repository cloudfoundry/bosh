require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::StateApplier do
    include Support::StemcellHelpers

    subject(:state_applier) { InstanceUpdater::StateApplier.new(instance_plan, agent_client, rendered_job_templates_cleaner) }

    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new({
          existing_instance: instance_model,
          desired_instance: DeploymentPlan::DesiredInstance.new(job),
          instance: instance,
          network_plans: [],
        })
    end
    let(:job) do
      job = instance_double('Bosh::Director::DeploymentPlan::Job',
        name: 'fake-job',
        spec: {'name' => 'job'},
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: {},
        vm_type: DeploymentPlan::VmType.new({'name' => 'fake-vm-type'}),
        stemcell: make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}),
        env: DeploymentPlan::Env.new({'key' => 'value'}),
        package_spec: {},
        persistent_disk_type: nil,
        can_run_as_errand?: false,
        link_spec: 'fake-link',
        compilation?: false,
        templates: [],
        properties: {})
    end
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
          name: 'fake-deployment',
          model: deployment,
        })
    end
    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:instance) { DeploymentPlan::Instance.create_from_job(job, 0, instance_state, plan, {}, nil, logger) }
    let(:instance_model) { Models::Instance.make(vm: vm_model) }
    let(:vm_model) { Models::Vm.make(cid: 'vm234') }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:rendered_job_templates_cleaner) { instance_double(RenderedJobTemplatesCleaner) }
    let(:instance_state) { 'started' }

    before { instance.bind_existing_instance_model(instance_model) }

    describe 'applying state' do
      before do
        allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client)
        allow(agent_client).to receive(:apply)
        allow(agent_client).to receive(:run_script)
        allow(agent_client).to receive(:start)
        allow(rendered_job_templates_cleaner).to receive(:clean)
      end

      it 'runs the start script' do
        expect(agent_client).to receive(:run_script).with('pre-start', {}).ordered
        expect(agent_client).to receive(:start).ordered
        state_applier.apply
      end

      it 'updates instance spec' do
        expect(agent_client).to receive(:apply).with(instance_plan.spec.as_apply_spec)
        state_applier.apply
        expect(instance_model.spec).to eq(instance_plan.spec.full_spec)
      end

      it 'cleans rendered templates after applying' do
        expect(agent_client).to receive(:apply).ordered
        expect(rendered_job_templates_cleaner).to receive(:clean).ordered
        state_applier.apply
      end

      context 'when instance state is stopped' do
        let(:instance_state) { 'stopped' }

        it 'does not run the start script' do
          expect(agent_client).to_not receive(:run_script)
          expect(agent_client).to_not receive(:start)
          state_applier.apply
        end
      end
    end
  end
end
