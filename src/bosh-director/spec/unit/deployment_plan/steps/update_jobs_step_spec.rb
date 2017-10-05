require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  module DeploymentPlan::Steps
    describe UpdateJobsStep do
      subject { UpdateJobsStep.new(base_job, deployment_plan, multi_job_updater) }
      let(:base_job) { Jobs::BaseJob.new }
      let(:ip_provider) { instance_double('Bosh::Director::DeploymentPlan::IpProvider') }
      let(:instance_group1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup') }

      let(:deployment_plan) do
        instance_double('Bosh::Director::DeploymentPlan::Planner',
          instance_groups: [instance_group1],
          ip_provider: ip_provider,
        )
      end

      let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }

      describe '#perform' do
        it 'logs and calls out to multi job updater' do
          expect(logger).to receive(:info).with('Updating instances')
          expect(multi_job_updater).to receive(:run).with(base_job, ip_provider, [instance_group1])

          subject.perform
        end
      end
    end
  end
end
