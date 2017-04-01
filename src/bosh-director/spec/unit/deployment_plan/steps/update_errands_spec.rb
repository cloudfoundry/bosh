require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  module DeploymentPlan::Steps
    describe UpdateErrandsStep do
      subject { DeploymentPlan::Steps::UpdateErrandsStep.new(deployment_plan) }
      let(:errand_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:errand_instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan', instance: errand_instance) }
      let(:errand_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', unignored_instance_plans: [errand_instance_plan]) }

      let(:ignored_errand_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:ignored_instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan', instance: ignored_errand_instance) }
      let(:ignored_errand_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', unignored_instance_plans: []) }

      let(:deployment_plan) do
        instance_double('Bosh::Director::DeploymentPlan::Planner',
          errand_instance_groups: [errand_instance_group, ignored_errand_instance_group],
        )
      end

      describe '#perform' do
        it 'updates variable sets of errand instance groups' do
          expect(errand_instance).to receive(:update_variable_set)
          expect(ignored_errand_instance).to_not receive(:update_variable_set)
          subject.perform
        end
      end
    end
  end
end
