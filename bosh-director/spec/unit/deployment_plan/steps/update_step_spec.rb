require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  describe DeploymentPlan::Steps::UpdateStep do
    subject { DeploymentPlan::Steps::UpdateStep.new(base_job, event_log, resource_pools, assembler, deployment_plan, multi_job_updater) }
    let(:base_job) { Jobs::BaseJob.new }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log', begin_stage: nil) }
    let(:resource_pools) { instance_double('Bosh::Director::DeploymentPlan::ResourcePools') }
    let(:assembler) { instance_double('Bosh::Director::DeploymentPlan::Assembler') }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
    let(:manifest) { ManifestHelper.default_legacy_manifest }
    let(:releases) { [] }
    let(:jobs) { instance_double('Array') }
    let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater') }

    before do
      allow(base_job).to receive(:logger).and_return(logger)
      allow(base_job).to receive(:track_and_log).and_yield
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
    end

    describe '#perform' do

      it 'runs deployment plan update stages in the correct order' do
        expect(assembler).to receive(:bind_dns).with(no_args).ordered
        expect(assembler).to receive(:delete_unneeded_vms).with(no_args).ordered
        expect(assembler).to receive(:delete_unneeded_instances).with(no_args).ordered
        expect(resource_pools).to receive(:update).with(no_args).ordered
        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        expect(assembler).to receive(:bind_instance_vms).with(no_args).ordered
        expect(assembler).to receive(:bind_configuration).with(no_args).ordered
        expect(deployment_plan).to receive(:jobs_starting_on_deploy).and_return(jobs)
        expect(multi_job_updater).to receive(:run).with(base_job, deployment_plan, jobs).ordered
        expect(resource_pools).to receive(:refill).with(no_args).ordered
        expect(deployment_plan).to receive(:persist_updates!).ordered
        expect(deployment_plan).to receive(:update_stemcell_references!).ordered
        subject.perform
      end

      context 'when perform fails' do
        let(:some_error) { RuntimeError.new('oops') }
        before do
          allow(assembler).to receive(:bind_dns).with(no_args)
          allow(assembler).to receive(:delete_unneeded_vms).with(no_args).and_raise(some_error)
        end

        it 'still updates the stemcell references' do
          expect(deployment_plan).to receive(:update_stemcell_references!)
          expect{
            subject.perform
          }.to raise_error(some_error)
        end
      end
    end
  end
end
