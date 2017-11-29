require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  module DeploymentPlan::Stages
    describe UpdateStage do
      subject { UpdateStage.new(base_job, deployment_plan, multi_job_updater, dns_encoder) }
      let(:dns_encoder) { Bosh::Director::DnsEncoder.new }
      let(:base_job) { Jobs::BaseJob.new }
      let(:pre_cleanup) { instance_double('Bosh::Director::DeploymentPlan::Stages::PreCleanupStage') }
      let(:update_active_vm_cpis) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateActiveVmCpisStage') }
      let(:setup) { instance_double('Bosh::Director::DeploymentPlan::Stages::SetupStage') }
      let(:download_packages_step) { instance_double('Bosh::Director::DeploymentPlan::Stages::DownloadPackagesStage')}
      let(:update_jobs) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateJobsStage') }
      let(:update_errands) { instance_double('Bosh::Director::DeploymentPlan::Stages::UpdateErrandsStage') }
      let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
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
        allow(SetupStage).to receive(:new).with(base_job, deployment_plan, vm_creator, anything, anything).and_return(setup)
        allow(DownloadPackagesStage).to receive(:new).with(base_job, deployment_plan).and_return(download_packages_step)
        allow(UpdateJobsStage).to receive(:new).with(base_job, deployment_plan, multi_job_updater).and_return(update_jobs)
        allow(UpdateErrandsStage).to receive(:new).with(base_job, deployment_plan).and_return(update_errands)
        allow(VmDeleter).to receive(:new).with(logger, false, Config.enable_virtual_delete_vms).and_return(vm_deleter)
        allow(VmCreator).to receive(:new).with(logger, vm_deleter, anything, anything, dns_encoder, anything).and_return(vm_creator)
        allow(CleanupStemcellReferencesStage).to receive(:new).with(deployment_plan).and_return(cleanup_stemcell_reference)
        allow(PersistDeploymentStage).to receive(:new).with(deployment_plan).and_return(persist_deployment)
      end

      describe '#perform' do
        it 'runs deployment plan update steps in the correct order' do
          expect(logger).to receive(:info).with('Updating deployment').ordered
          expect(pre_cleanup).to receive(:perform).ordered
          expect(update_active_vm_cpis).to receive(:perform).ordered
          expect(setup).to receive(:perform).ordered
          allow(deployment_plan).to receive(:availability_zones).and_return([]).ordered
          expect(download_packages_step).to receive(:perform).ordered
          expect(update_jobs).to receive(:perform).ordered
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
            allow(logger).to receive(:info).and_raise(some_error)
          end

          it 'still updates the stemcell references' do
            expect(cleanup_stemcell_reference).to receive(:perform)

            expect {
              subject.perform
            }.to raise_error(some_error)
          end
        end
      end
    end
  end
end
