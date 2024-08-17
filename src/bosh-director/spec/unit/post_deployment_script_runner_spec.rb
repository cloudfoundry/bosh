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

      let(:instance) do
        instance = FactoryBot.create(:models_instance, state: 'started')
        vm = Models::Vm.make(instance_id: instance.id)
        instance.active_vm = vm
        instance
      end

      before do
        allow(Bosh::Director::Models::Instance).to receive(:filter).and_return(instance_data_set)
        allow(instance_data_set).to receive(:reject).and_return([instance, instance])
        allow(Bosh::Director::AgentClient).to receive(:with_agent_id).and_return(agent)
      end

      it "runs 'post_deploy' on each instance of that deployment after resurrection" do
        expect(agent).to receive(:run_script).with('post-deploy', {}).ordered
        expect(agent).to receive(:run_script).with('post-deploy', {}).ordered
        described_class.run_post_deploys_after_resurrection({})
      end

      it "runs 'post_deploy' on each instance of that deployment after deployment" do
        expect(agent).to receive(:run_script).twice
        described_class.run_post_deploys_after_deployment(deployment_plan)
      end
    end
  end
end
