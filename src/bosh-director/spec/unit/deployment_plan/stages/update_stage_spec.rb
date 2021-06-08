require 'spec_helper'
require 'bosh/director/deployment_plan/multi_instance_group_updater'
require 'bosh/director/instance_group_updater'

module Bosh::Director
  module DeploymentPlan::Stages
    describe UpdateStage do
      subject { UpdateStage.new(base_job, deployment_plan, multi_instance_group_updater, dns_encoder, link_provider_intents) }
      let(:link_provider_intents) { [] }
      let(:dns_encoder) { Bosh::Director::DnsEncoder.new }
      let(:base_job) { Jobs::BaseJob.new }
      let(:pre_cleanup) { instance_double('Bosh::Director::DeploymentPlan::Stages::PreCleanupStage') }
      let(:update_active_vm_cpis) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateActiveVmCpisStage') }
      let(:setup) { instance_double('Bosh::Director::DeploymentPlan::Stages::SetupStage') }
      let(:download_packages_step) { instance_double('Bosh::Director::DeploymentPlan::Stages::DownloadPackagesStage')}
      let(:update_instance_groups) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateInstanceGroupsStage') }
      let(:update_errands) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateErrandsStage') }
      let(:multi_instance_group_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater', run: nil) }
      let(:vm_deleter) { instance_double('Bosh::Director::VmDeleter') }
      let(:vm_creator) { instance_double('Bosh::Director::VmCreator') }
      let(:cleanup_stemcell_reference) { instance_double('Bosh::Director::DeploymentPlan::Stages::CleanupStemcellReferencesStage') }
      let(:persist_deployment) { instance_double('Bosh::Director::DeploymentPlan::Stages::PersistDeploymentStage') }
      let(:template_blob_cache) { instance_double'Bosh::Director::Core::Templates::TemplateBlobCache' }

      let(:deployment_plan) do
        instance_double('Bosh::Director::DeploymentPlan::Planner',
          template_blob_cache: template_blob_cache,
        )
      end

      before do
        allow(PreCleanupStage).to receive(:new).with(base_job.logger, deployment_plan).and_return(pre_cleanup)
        allow(UpdateActiveVmCpisStage).to receive(:new).with(base_job.logger, deployment_plan).and_return(update_active_vm_cpis)
        allow(SetupStage).to receive(:new).with(
          base_job: base_job,
          deployment_plan: deployment_plan,
          vm_creator: vm_creator,
          local_dns_records_repo: anything,
          local_dns_aliases_repo: anything,
          dns_publisher: anything,
        ).and_return(setup)
        allow(DownloadPackagesStage).to receive(:new).with(base_job, deployment_plan).and_return(download_packages_step)
        allow(UpdateInstanceGroupsStage).to receive(:new)
          .with(base_job, deployment_plan, multi_instance_group_updater).and_return(update_instance_groups)
        allow(UpdateErrandsStage).to receive(:new).with(base_job, deployment_plan).and_return(update_errands)
        allow(VmDeleter).to receive(:new).with(logger, false, Config.enable_virtual_delete_vms).and_return(vm_deleter)
        allow(VmCreator).to receive(:new)
          .with(logger, anything, dns_encoder, anything, link_provider_intents).and_return(vm_creator)
        allow(CleanupStemcellReferencesStage).to receive(:new).with(deployment_plan).and_return(cleanup_stemcell_reference)
        allow(PersistDeploymentStage).to receive(:new).with(deployment_plan).and_return(persist_deployment)
      end

      describe '#perform' do
        before do
          allow(logger).to receive(:info)
          allow(pre_cleanup).to receive(:perform)
          allow(update_active_vm_cpis).to receive(:perform)
          allow(setup).to receive(:perform)
          allow(deployment_plan).to receive(:availability_zones)
          allow(download_packages_step).to receive(:perform)
          allow(update_instance_groups).to receive(:perform)
          allow(update_errands).to receive(:perform)
          allow(persist_deployment).to receive(:perform)
        end

        it 'runs deployment plan update steps in the correct order' do
          expect(logger).to receive(:info).with('Updating deployment').ordered
          expect(pre_cleanup).to receive(:perform).ordered
          expect(update_active_vm_cpis).to receive(:perform).ordered
          expect(setup).to receive(:perform).ordered
          expect(download_packages_step).to receive(:perform).ordered
          expect(update_instance_groups).to receive(:perform).ordered
          expect(update_errands).to receive(:perform).ordered
          expect(logger).to receive(:info).with('Committing updates').ordered
          expect(persist_deployment).to receive(:perform).ordered
          expect(logger).to receive(:info).with('Finished updating deployment').ordered
          expect(cleanup_stemcell_reference).to receive(:perform).ordered

          subject.perform
        end

        context 'when perform fails' do
          let(:some_error) { RuntimeError.new('oops') }

          before do
            allow(persist_deployment).to receive(:perform).and_raise(some_error)
          end

          it 'does not update the stemcell references' do
            expect(cleanup_stemcell_reference).to_not receive(:perform)

            expect {
              subject.perform
            }.to raise_error(some_error)
          end
        end
      end
    end
  end
end
