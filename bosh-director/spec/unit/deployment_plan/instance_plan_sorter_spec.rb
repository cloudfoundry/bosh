require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlanSorter do
    let (:instance_plan_sorter) { InstancePlanSorter.new(logger) }

    describe '#sort' do
      let (:desired_instance) { DesiredInstance.new() }
      let (:job) { instance_double(Job, name: 'job_name') }
      let (:bootstrap_az) { AvailabilityZone.new('az3_name', {}) }
      let (:bootstrap_instance) {
        bootstrap_instance = Instance.new(job, 0, 'started', nil, {}, bootstrap_az, true, logger)
        bootstrap_instance.bind_existing_instance_model(BD::Models::Instance.make(uuid: 'a-uuid', index: 0, job: 'job_name'))
        bootstrap_instance
      }

      let (:bootstrap_instance_plan) { InstancePlan.new(
        existing_instance: bootstrap_instance.model,
        desired_instance: desired_instance,
        instance: bootstrap_instance,
        network_plans: []) }

      context 'when there are multiple instance plans' do
        let (:az_2) { AvailabilityZone.new('az2_name', {}) }
        let (:instance_in_bootstrap_az) {
          instance = Instance.new(job, 4, 'started', nil, {}, bootstrap_az, false, logger)
          instance.bind_existing_instance_model(BD::Models::Instance.make(uuid: 'bb-uuid1', index: 4, job: 'job_name'))
          instance
        }

        let (:instance_plan_in_bootstrap_az) { InstancePlan.new(
          existing_instance: instance_in_bootstrap_az.model,
          desired_instance: desired_instance,
          instance: instance_in_bootstrap_az,
          network_plans: []) }

        it 'should put the bootstrap node first' do
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan_in_bootstrap_az, bootstrap_instance_plan])
          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az])
        end

        it 'should sort instance plans in alphanum in the same az' do
          instance2_in_bootstrap_az = Instance.new(job, 2, 'started', nil, {}, bootstrap_az, false, logger)
          instance2_in_bootstrap_az.bind_existing_instance_model(BD::Models::Instance.make(uuid: 'bb-uuid2', index: 2, job: 'job_name'))
          instance_plan2_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance2_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_in_bootstrap_az,
            network_plans: [])
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])
          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_in_bootstrap_az])
        end

        it 'should sort instance plans in alphanum order in alphanum sorted az' do
          instance2_not_in_bootstrap_az = Instance.new(job, 2, 'started', nil, {}, az_2, false, logger)
          instance2_not_in_bootstrap_az.bind_existing_instance_model(BD::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
          instance_plan2_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance2_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_not_in_bootstrap_az,
            network_plans: [])
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_not_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])

          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_not_in_bootstrap_az])
        end

        it 'should set instance plans from az with bootstrap node first' do
          instance2_not_in_bootstrap_az = Instance.new(job, 2, 'started', nil, {}, az_2, false, logger)
          instance2_not_in_bootstrap_az.bind_existing_instance_model(BD::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
          instance_plan2_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance2_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_not_in_bootstrap_az,
            network_plans: [])

          instance3_not_in_bootstrap_az = Instance.new(job, 3, 'started', nil, {}, az_2, false, logger)
          instance3_not_in_bootstrap_az.bind_existing_instance_model(BD::Models::Instance.make(uuid: '2-uuid2', index: 3, job: 'job_name'))
          instance_plan3_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance3_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance3_not_in_bootstrap_az,
            network_plans: [])
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_not_in_bootstrap_az, instance_plan3_not_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])

          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_not_in_bootstrap_az, instance_plan3_not_in_bootstrap_az])
        end

        context 'when instance does not have az' do
          it 'should sort it without errors' do
            instance2_without_az = Instance.new(job, 2, 'started', nil, {}, nil, false, logger)
            instance2_without_az.bind_existing_instance_model(BD::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
            instance_plan2_without_az = InstancePlan.new(
              existing_instance: instance2_without_az.model,
              desired_instance: desired_instance,
              instance: instance2_without_az,
              network_plans: [])
            sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_without_az, bootstrap_instance_plan])

            expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan2_without_az])
          end
        end
      end

      context 'when there is a single instance plan' do
        it 'does not raise any errors and return 1 instance plan' do
          sorted_instance_plans = instance_plan_sorter.sort([bootstrap_instance_plan])
          expect(sorted_instance_plans.count).to eq(1)
        end
      end

      context 'when there is no instance plan' do
        it 'should return empty array' do
          expect(instance_plan_sorter.sort([]).count).to eq(0)
        end
      end
    end
  end
end
