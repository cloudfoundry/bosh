require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Steps
    describe SetupStep do
      describe 'deployment prepare & update', truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
        subject { SetupStep.new(base_job, deployment_plan, vm_creator) }

        let(:base_job) { instance_double(Jobs::BaseJob, logger: logger) }
        let(:vm_creator) { instance_double(VmCreator) }

        let(:instance_plans_with_hot_swap_and_needs_shutdown) { [instance_double(DeploymentPlan::InstancePlan)] }
        let(:instance_plans_with_missing_vms) { [instance_double(DeploymentPlan::InstancePlan)] }
        let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
        let(:tags) { {'some' => 'tags'} }

        let(:deployment_plan) do
          instance_double(DeploymentPlan::Planner,
            instance_plans_with_hot_swap_and_needs_shutdown: instance_plans_with_hot_swap_and_needs_shutdown,
            instance_plans_with_missing_vms: instance_plans_with_missing_vms,
            ip_provider: ip_provider,
            tags: tags)
        end

        context 'when the director database contains no instances' do
          it 'creates vms for instance groups missing vms and checkpoints task' do
            expect(vm_creator).to receive(:create_for_instance_plans).with(
              instance_plans_with_missing_vms + instance_plans_with_hot_swap_and_needs_shutdown,
              ip_provider,
              tags,
            )

            expect(base_job).to receive(:task_checkpoint)
            subject.perform
          end
        end
      end
    end
  end
end
