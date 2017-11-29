require 'spec_helper'
require 'bosh/director/dns/local_dns_encoder_manager'

module Bosh::Director
  module DeploymentPlan::Stages
    describe SetupStage do
      describe 'deployment prepare & update' do
        subject { SetupStage.new(base_job, deployment_plan, vm_creator, local_dns_repo, dns_publisher) }

        let(:base_job) { instance_double(Jobs::BaseJob, logger: logger) }
        let(:vm_creator) { instance_double(VmCreator) }

        let(:instance_model_hot_swap) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_hot_swap) { instance_double(DeploymentPlan::Instance, model: instance_model_hot_swap) }
        let(:instance_plans_with_hot_swap_and_needs_shutdown) { [instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_hot_swap)] }

        let(:instance_model_0) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_0) { instance_double(DeploymentPlan::Instance, model: instance_model_0) }
        let(:instance_model_1) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_1) { instance_double(DeploymentPlan::Instance, model: instance_model_1) }

        let(:instance_plans_with_missing_vms) do
          [
            instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_0),
            instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_1)
          ]
        end
        let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
        let(:tags) { { 'some' => 'tags' } }
        let(:local_dns_repo) { instance_double(LocalDnsRepo) }
        let(:dns_publisher) { instance_double(BlobstoreDnsPublisher) }

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

        before do
          allow(vm_creator).to receive(:create_for_instance_plans)
          allow(base_job).to receive(:task_checkpoint)
          allow(local_dns_repo).to receive(:update_for_instance)
          allow(dns_publisher).to receive(:publish_and_broadcast)
        end

        context 'when deployment will be using named AZs' do
          it 'registers the persistent IDs for those AZ names' do
            expect(Bosh::Director::LocalDnsEncoderManager).to receive(:persist_az_names).with(['zone1', 'zone2'])
            subject.perform
          end
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

          it 'updates and publishes local dns records for the missing plans' do
            expect(local_dns_repo).to receive(:update_for_instance).with(instance_model_0).ordered
            expect(local_dns_repo).to receive(:update_for_instance).with(instance_model_1).ordered
            expect(dns_publisher).to receive(:publish_and_broadcast).ordered
            subject.perform
          end
        end
      end
    end
  end
end
