require 'spec_helper'
require 'bosh/director/dns/local_dns_encoder_manager'

module Bosh::Director
  module DeploymentPlan::Stages
    describe SetupStage do
      describe 'deployment prepare & update' do
        subject do
          SetupStage.new(
            base_job: base_job,
            deployment_plan: deployment_plan,
            vm_creator: vm_creator,
            local_dns_records_repo: local_dns_records_repo,
            local_dns_aliases_repo: local_dns_aliases_repo,
            dns_publisher: dns_publisher,
          )
        end

        let(:base_job) { instance_double(Jobs::BaseJob, logger: per_spec_logger) }
        let(:vm_creator) { instance_double(VmCreator) }

        let(:instance_model_create_swap_delete) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_create_swap_delete) do
          instance_double(DeploymentPlan::Instance, model: instance_model_create_swap_delete)
        end
        let(:instance_plans_with_create_swap_delete_and_needs_duplicate_vm) do
          [instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_create_swap_delete)]
        end

        let(:instance_model_0) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_0) { instance_double(DeploymentPlan::Instance, model: instance_model_0) }
        let(:instance_model_1) { instance_double(Models::Instance) }
        let(:deployment_plan_instance_1) { instance_double(DeploymentPlan::Instance, model: instance_model_1) }
        let(:deployment_plan_instance_plan_0) do
          instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_0)
        end
        let(:deployment_plan_instance_plan_1) do
          instance_double(DeploymentPlan::InstancePlan, instance: deployment_plan_instance_1)
        end

        let(:instance_plans_with_missing_vms) do
          [
            deployment_plan_instance_plan_0,
            deployment_plan_instance_plan_1,
          ]
        end
        let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
        let(:tags) do
          { 'some' => 'tags' }
        end
        let(:local_dns_records_repo) { instance_double(LocalDnsRecordsRepo) }
        let(:local_dns_aliases_repo) { instance_double(LocalDnsAliasesRepo) }
        let(:dns_publisher) { instance_double(BlobstoreDnsPublisher) }
        let(:deployment_model) { instance_double(Models::Deployment) }

        let(:deployment_plan) do
          instance_double(
            DeploymentPlan::Planner,
            instance_plans_with_create_swap_delete_and_needs_duplicate_vm:
              instance_plans_with_create_swap_delete_and_needs_duplicate_vm,
            instance_plans_with_missing_vms: instance_plans_with_missing_vms,
            skipped_instance_plans_with_create_swap_delete_and_needs_duplicate_vm: [],
            ip_provider: ip_provider,
            availability_zones: [
              instance_double(DeploymentPlan::AvailabilityZone, name: 'zone1'),
              instance_double(DeploymentPlan::AvailabilityZone, name: 'zone2'),
            ],
            model: deployment_model,
            tags: tags,
          )
        end

        before do
          allow(vm_creator).to receive(:create_for_instance_plans)
          allow(base_job).to receive(:task_checkpoint)
          allow(local_dns_records_repo).to receive(:update_for_instance)
          allow(local_dns_aliases_repo).to receive(:update_for_deployment)
          allow(dns_publisher).to receive(:publish_and_broadcast)
        end

        context 'when deployment will be using named AZs' do
          it 'registers the persistent IDs for those AZ names' do
            expect(Bosh::Director::LocalDnsEncoderManager).to receive(:persist_az_names).with(%w[zone1 zone2])
            subject.perform
          end
        end

        context 'when the director database contains no instances' do
          it 'creates vms for instance groups missing vms and checkpoints task' do
            expect(vm_creator).to receive(:create_for_instance_plans).with(
              instance_plans_with_missing_vms + instance_plans_with_create_swap_delete_and_needs_duplicate_vm,
              ip_provider,
              tags,
            )

            expect(base_job).to receive(:task_checkpoint)
            subject.perform
          end

          it 'updates and publishes local dns information' do
            expect(local_dns_records_repo).to receive(:update_for_instance).with(deployment_plan_instance_plan_0).ordered
            expect(local_dns_records_repo).to receive(:update_for_instance).with(deployment_plan_instance_plan_1).ordered
            expect(local_dns_aliases_repo).to receive(:update_for_deployment).with(deployment_model)
            expect(dns_publisher).to receive(:publish_and_broadcast).ordered

            subject.perform
          end
        end
      end
    end
  end
end
