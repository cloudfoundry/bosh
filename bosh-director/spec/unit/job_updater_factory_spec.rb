require 'spec_helper'

describe Bosh::Director::JobUpdaterFactory do
  subject(:job_updater_factory) { described_class.new(blobstore) }

  let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

  describe '#new_job_updater' do
    it 'returns job updater' do
      deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      job = instance_double('Bosh::Director::DeploymentPlan::Job')

      job_renderer = instance_double('Bosh::Director::JobRenderer')
      expect(Bosh::Director::JobRenderer).to receive(:new).
        with(job, blobstore).
        and_return(job_renderer)

      job_updater = instance_double('Bosh::Director::JobUpdater')
      expect(Bosh::Director::JobUpdater).to receive(:new).
        with(deployment_plan, job, job_renderer).
        and_return(job_updater)

      expect(job_updater_factory.new_job_updater(deployment_plan, job)).to eq(job_updater)
    end
  end
end
