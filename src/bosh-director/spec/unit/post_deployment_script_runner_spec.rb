require 'spec_helper'

module Bosh::Director
  describe PostDeploymentScriptRunner do
    context 'Given a deployment instance' do
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', instance_groups: [instance_group]) }
      let(:instance_data_set) { instance_double('Sequel::Dataset') }
      let(:instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', instances: [instance_plan, instance_plan]) }
      let(:instance_plan) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance, agent_client: agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:vm) { Models::Vm.make }
      let(:instance) do
        instance = Models::Instance.make(state: 'started')
        instance.add_vm(vm)
        instance.update(active_vm: vm)
      end

      before do
        allow(Bosh::Director::Models::Instance).to receive(:filter).and_return(instance_data_set)
        allow(instance_data_set).to receive(:exclude).and_return(instance_data_set)
        allow(instance_data_set).to receive(:all).and_return([instance, instance])
        allow(Bosh::Director::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)
      end

      it "runs 'post_deploy' on each instance of that deployment after resurrection" do
        allow(Bosh::Director::Config).to receive(:enable_post_deploy).and_return(true)
        expect(agent).to receive(:run_script).with('post-deploy', {}).ordered
        expect(agent).to receive(:run_script).with('post-deploy', {}).ordered
        described_class.run_post_deploys_after_resurrection({})
      end

      it "runs 'post_deploy' on each instance of that deployment after deployment" do
        allow(Bosh::Director::Config).to receive(:enable_post_deploy).and_return(true)
        expect(agent).to receive(:run_script).twice
        described_class.run_post_deploys_after_deployment(deployment_plan)
      end
    end
  end
end
