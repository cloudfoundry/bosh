require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstancePlanner do
  describe '#create_instance_plans' do
    it 'returns instance plans for each job' do
      logger = instance_double(Logger)
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(logger)

      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'foo-job')
      existing_instance_thats_desired = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 0)
      existing_instance_thats_obsolete = Bosh::Director::Models::Instance.make(job: 'foo-job', index: 1)
      desired_instance_thats_new = instance_double(Bosh::Director::DeploymentPlan::Instance, job: job, index: 2)
      desired_instance_that_exists = instance_double(Bosh::Director::DeploymentPlan::Instance, job: job, index: 0)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      desired_instances = [desired_instance_thats_new, desired_instance_that_exists]
      instance_plans = instance_planner.create_instance_plans(existing_instances, desired_instances)

      expect(instance_plans.count).to eq(3)

      existing_instance_plan = instance_plans.find {|plan| !plan.new? && !plan.obsolete? }
      obsolete_instance_plan = instance_plans.find {|plan| plan.obsolete? }
      new_instance_plan = instance_plans.find {|plan| plan.new? }

      expect(existing_instance_plan.instance).to eq(desired_instance_that_exists)
      expect(existing_instance_plan.existing_instance).to eq(existing_instance_thats_desired)

      expect(obsolete_instance_plan.instance.model).to eq(existing_instance_thats_obsolete)

      expect(new_instance_plan.instance).to eq(desired_instance_thats_new)
      expect(new_instance_plan.existing_instance).to be_nil
    end
  end
end
