require 'spec_helper'
require 'bosh/director/dns/local_dns_encoder_manager'

module Bosh::Director
  module DeploymentPlan::Steps
    describe DownloadPackagesStep do
      subject { DownloadPackagesStep.new(base_job, deployment_plan) }

      let(:base_job) { instance_double(Jobs::BaseJob, logger: logger) }

      let(:swap_agent_client) {instance_double(AgentClient)}
      let(:instance0_agent_client) {instance_double(AgentClient)}
      let(:instance1_agent_client) {instance_double(AgentClient)}

      let(:instance_model_hot_swap) { instance_double(Models::Instance, agent_id: 'swap_agent') }
      let(:deployment_plan_instance_hot_swap) { instance_double(DeploymentPlan::Instance, model: instance_model_hot_swap) }
      let(:swap_instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_hot_swap) }
      let(:instance_plans_with_hot_swap_and_needs_shutdown) { [swap_instance_plan] }
      let(:swap_instance_spec) { instance_double(DeploymentPlan::InstanceSpec) }

      let(:instance_model_0) { instance_double(Models::Instance, agent_id: 'instance0_agent') }
      let(:deployment_plan_instance_0) { instance_double(DeploymentPlan::Instance, model: instance_model_0) }
      let(:instance0_instance_spec) { instance_double(DeploymentPlan::InstanceSpec) }
      let(:instance0_plan) { instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_0) }
      let(:instance_model_1) { instance_double(Models::Instance, agent_id: 'instance1_agent') }
      let(:deployment_plan_instance_1) { instance_double(DeploymentPlan::Instance, model: instance_model_1) }
      let(:instance1_instance_spec) { instance_double(DeploymentPlan::InstanceSpec) }
      let(:instance1_plan) { instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_1) }

      let(:instance_plans_with_missing_vms) do
        [
          instance0_plan,
          instance1_plan,
        ]
      end
      let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
      let(:tags) { { 'some' => 'tags' } }

      let(:deployment_plan) do
        instance_double(DeploymentPlan::Planner,
          instance_plans_with_hot_swap_and_needs_shutdown: instance_plans_with_hot_swap_and_needs_shutdown,
          instance_plans_with_missing_vms: instance_plans_with_missing_vms,
          ip_provider: ip_provider,
          availability_zones: [
            instance_double(DeploymentPlan::AvailabilityZone, name: 'zone1'),
            instance_double(DeploymentPlan::AvailabilityZone, name: 'zone2'),
          ],
          tags: tags)
      end

      let(:swap_instance_spec) {instance_double(DeploymentPlan::InstanceSpec)}
      let(:instance0_instance_spec) {instance_double(DeploymentPlan::InstanceSpec)}
      let(:instance1_instance_spec) {instance_double(DeploymentPlan::InstanceSpec)}

      before do
        allow(DeploymentPlan::InstanceSpec).to receive(:create_from_instance_plan).with(swap_instance_plan).and_return(swap_instance_spec)
        allow(DeploymentPlan::InstanceSpec).to receive(:create_from_instance_plan).with(instance0_plan).and_return(instance0_instance_spec)
        allow(DeploymentPlan::InstanceSpec).to receive(:create_from_instance_plan).with(instance1_plan).and_return(instance1_instance_spec)

        allow(swap_instance_spec).to receive(:as_jobless_apply_spec).and_return('swap_spec')
        allow(instance0_instance_spec).to receive(:as_jobless_apply_spec).and_return('instance0_spec')
        allow(instance1_instance_spec).to receive(:as_jobless_apply_spec).and_return('instance1_spec')
      end

      describe '#perform' do
        before do
          allow(AgentClient).to receive(:with_agent_id).with('swap_agent').and_return(swap_agent_client)
          allow(AgentClient).to receive(:with_agent_id).with('instance0_agent').and_return(instance0_agent_client)
          allow(AgentClient).to receive(:with_agent_id).with('instance1_agent').and_return(instance1_agent_client)
        end

        it 'calls prepare for all agents with instances in deployment_plan that are newly created or hotswap' do
          expect(swap_agent_client).to receive(:prepare).with('swap_spec')
          expect(instance0_agent_client).to receive(:prepare).with('instance0_spec')
          expect(instance1_agent_client).to receive(:prepare).with('instance1_spec')

          subject.perform
        end
      end
    end
  end
end
