require 'spec_helper'
require 'bosh/director/dns/local_dns_encoder_manager'

module Bosh::Director
  module DeploymentPlan
    module Stages
      describe DownloadPackagesStage do
        subject { DownloadPackagesStage.new(base_job, deployment_plan) }

        let(:base_job) { instance_double(Jobs::BaseJob, logger: logger) }

        let(:swap_instance_plan) { instance_double(DeploymentPlan::InstancePlan) }
        let(:instance_plans_with_hot_swap_and_needs_shutdown) { [swap_instance_plan] }

        let(:instance0_plan) { instance_double(DeploymentPlan::InstancePlan) }
        let(:instance1_plan) { instance_double(DeploymentPlan::InstancePlan) }
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

        let(:instance0_prepare_step) { instance_double Steps::PrepareInstanceStep }
        let(:instance1_prepare_step) { instance_double Steps::PrepareInstanceStep }
        let(:swap_prepare_step) { instance_double Steps::PrepareInstanceStep }

        before do
          allow(Steps::PrepareInstanceStep).to receive(:new).with(instance0_plan, use_active_vm: false).and_return instance0_prepare_step
          allow(Steps::PrepareInstanceStep).to receive(:new).with(instance1_plan, use_active_vm: false).and_return instance1_prepare_step
          allow(Steps::PrepareInstanceStep).to receive(:new).with(swap_instance_plan, use_active_vm: false).and_return swap_prepare_step

          allow(swap_instance_plan).to receive_message_chain(:instance, :model, :to_s)
          allow(instance0_plan).to receive_message_chain(:instance, :model, :to_s)
          allow(instance1_plan).to receive_message_chain(:instance, :model, :to_s)
        end

        describe '#perform' do
          it 'calls prepare for all agents with instances in deployment_plan that are newly created or hotswap' do
            expect(swap_prepare_step).to receive :perform
            expect(instance0_prepare_step).to receive :perform
            expect(instance1_prepare_step).to receive :perform

            subject.perform
          end
        end
      end
    end
  end
end
