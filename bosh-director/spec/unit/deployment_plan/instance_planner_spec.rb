require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstancePlanner do
  let(:logger) { instance_double(Logger, debug: nil) }
  let(:instance_repo) { class_double(Bosh::Director::DeploymentPlan::Instance) }
  describe '#plan_job_instances' do
    it 'returns instance plans for existing and new instances' do
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger, instance_repo)

      deployment = instance_double(Bosh::Director::DeploymentPlan::Planner)
      az = Bosh::Director::DeploymentPlan::AvailabilityZone.new({
          'name' => 'foo-az',
          'cloud_properties' => {}
        })
      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job', availability_zones: [az])
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_desired_state = {'foo' => 'bar'}
      desired_instance_thats_new = Bosh::Director::DeploymentPlan::DesiredInstance.new(job, nil, deployment)
      desired_instance_that_exists = Bosh::Director::DeploymentPlan::DesiredInstance.new(job, nil, deployment)

      instance_for_the_existing_instance = instance_double(Bosh::Director::DeploymentPlan::Instance)
      instance_for_the_new_instance = instance_double(Bosh::Director::DeploymentPlan::Instance)

      allow(instance_repo).to receive(:fetch_existing).
          with(desired_instance_that_exists, existing_instance_thats_desired, existing_instance_thats_desired_state, 0, az, logger) { instance_for_the_existing_instance }
      allow(instance_repo).to receive(:create).
          with(desired_instance_thats_new, 1, az, logger) { instance_for_the_new_instance }

      existing_instances = [existing_instance_thats_desired]
      states_by_existing_instance = {
        existing_instance_thats_desired => existing_instance_thats_desired_state
      }
      desired_instances = [desired_instance_thats_new, desired_instance_that_exists]
      instance_plans = instance_planner.plan_job_instances(job, desired_instances, existing_instances, states_by_existing_instance)

      expect(instance_plans.count).to eq(2)

      existing_instance_plan = instance_plans.find {|plan| !plan.new? && !plan.obsolete? }
      new_instance_plan = instance_plans.find {|plan| plan.new? }

      expect(existing_instance_plan.desired_instance).to eq(desired_instance_that_exists)
      expect(existing_instance_plan.instance).to eq(instance_for_the_existing_instance)
      expect(existing_instance_plan.existing_instance).to eq(existing_instance_thats_desired)

      expect(new_instance_plan.desired_instance).to eq(desired_instance_thats_new)
      expect(new_instance_plan.instance).to eq(instance_for_the_new_instance)
      expect(new_instance_plan.existing_instance).to be_nil
      expect(new_instance_plan).to be_new
    end

    it 'returns instance plans for existing and obsolete' do
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger, instance_repo)

      deployment = instance_double(Bosh::Director::DeploymentPlan::Planner)
      az = Bosh::Director::DeploymentPlan::AvailabilityZone.new({
          'name' => 'foo-az',
          'cloud_properties' => {}
        })
      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job', availability_zones: [az])
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_desired_state = {'foo' => 'bar'}
      existing_instance_thats_obsolete = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 1)
      existing_instance_thats_obsolete_state = {'bar' => 'baz'}
      desired_instance_that_exists = Bosh::Director::DeploymentPlan::DesiredInstance.new(job, nil, deployment)

      instance_for_the_existing_instance = instance_double(Bosh::Director::DeploymentPlan::Instance)
      instance_for_the_obsolete_instance = instance_double(Bosh::Director::DeploymentPlan::Instance)

      allow(instance_repo).to receive(:fetch_existing).
          with(desired_instance_that_exists, existing_instance_thats_desired, existing_instance_thats_desired_state, 0, az, logger) { instance_for_the_existing_instance }
      allow(instance_repo).to receive(:fetch_obsolete).
          with(existing_instance_thats_obsolete, logger) { instance_for_the_obsolete_instance }

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      states_by_existing_instance = {
        existing_instance_thats_desired => existing_instance_thats_desired_state,
        existing_instance_thats_obsolete => existing_instance_thats_obsolete_state,
      }
      desired_instances = [desired_instance_that_exists]
      instance_plans = instance_planner.plan_job_instances(job, desired_instances, existing_instances, states_by_existing_instance)

      expect(instance_plans.count).to eq(2)

      existing_instance_plan = instance_plans.find {|plan| !plan.new? && !plan.obsolete? }
      obsolete_instance_plan = instance_plans.find {|plan| plan.obsolete? }

      expect(existing_instance_plan.desired_instance).to eq(desired_instance_that_exists)
      expect(existing_instance_plan.instance).to eq(instance_for_the_existing_instance)
      expect(existing_instance_plan.existing_instance).to eq(existing_instance_thats_desired)

      expect(obsolete_instance_plan.instance).to eq(instance_for_the_obsolete_instance)
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan).to be_obsolete
    end
  end

  describe '#plan_obsolete_jobs' do
    it 'returns instance plans for each job' do
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger, instance_repo)

      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job')
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_obsolete = Bosh::Director::Models::Instance.make(job: 'bar-job', index: 1)

      instance_for_the_obsolete_instance = instance_double(Bosh::Director::DeploymentPlan::Instance)

      allow(instance_repo).to receive(:fetch_obsolete).
          with(existing_instance_thats_obsolete, logger) { instance_for_the_obsolete_instance }

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      instance_plans = instance_planner.plan_obsolete_jobs([job], existing_instances)

      expect(instance_plans.count).to eq(1)

      obsolete_instance_plan = instance_plans.first
      expect(obsolete_instance_plan.instance).to eq(instance_for_the_obsolete_instance)
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan).to be_obsolete
    end
  end
end
