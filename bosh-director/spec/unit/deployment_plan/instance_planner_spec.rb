require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstancePlanner do
  describe '#plan_job_instances' do
    it 'returns instance plans for each job' do
      logger = instance_double(Logger)
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger)

      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job')
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_obsolete = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 1)
      desired_instance_thats_new = instance_double(Bosh::Director::DeploymentPlan::Instance, job: job, index: 2)
      desired_instance_that_exists = instance_double(Bosh::Director::DeploymentPlan::Instance, job: job, index: 0)

      allow(desired_instance_thats_new).to receive(:bind_new_instance_model)
      allow(desired_instance_that_exists).to receive(:bind_existing_instance_model).with(existing_instance_thats_desired)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      desired_instances = [desired_instance_thats_new, desired_instance_that_exists]
      instance_plans = instance_planner.plan_job_instances(job, desired_instances, existing_instances)

      expect(instance_plans.count).to eq(3)

      existing_instance_plan = instance_plans.find {|plan| !plan.new? && !plan.obsolete? }
      obsolete_instance_plan = instance_plans.find {|plan| plan.obsolete? }
      new_instance_plan = instance_plans.find {|plan| plan.new? }

      expect(existing_instance_plan.desired_instance).to eq(desired_instance_that_exists)
      expect(existing_instance_plan.instance).to eq(desired_instance_that_exists)
      expect(existing_instance_plan.existing_instance).to eq(existing_instance_thats_desired)

      expect(obsolete_instance_plan.instance.model).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan).to be_obsolete

      expect(new_instance_plan.desired_instance).to eq(desired_instance_thats_new)
      expect(new_instance_plan.instance).to eq(desired_instance_thats_new)
      expect(new_instance_plan.existing_instance).to be_nil
      expect(new_instance_plan).to be_new
    end
  end

  describe '#plan_obsolete_jobs' do
    it 'returns instance plans for each job' do
      logger = instance_double(Logger)
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger)

      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job')
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_obsolete = Bosh::Director::Models::Instance.make(job: 'bar-job', index: 1)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      instance_plans = instance_planner.plan_obsolete_jobs([job], existing_instances)

      expect(instance_plans.count).to eq(1)

      obsolete_instance_plan = instance_plans.first
      expect(obsolete_instance_plan.instance.model).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan).to be_obsolete
    end
  end
end
