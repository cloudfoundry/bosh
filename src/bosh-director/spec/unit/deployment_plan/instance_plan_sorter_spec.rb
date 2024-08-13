require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlanSorter do
    let(:instance_plan_sorter) { InstancePlanSorter.new(logger) }

    describe '#sort' do
      let(:desired_instance) { DesiredInstance.new(instance_group) }
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:instance_group) { FactoryBot.build(:deployment_plan_instance_group, name: 'job_name') }
      let(:deployment_model) { FactoryBot.create(:models_deployment, name: 'my-deployment') }
      let(:bootstrap_az) { AvailabilityZone.new('bootstrap_name', {}) }
      let(:bootstrap_instance) do
        bootstrap_instance = Instance.create_from_instance_group(instance_group, 0, 'started', deployment_model, {}, bootstrap_az, logger, variables_interpolator)
        bootstrap_instance.bind_existing_instance_model(
          Bosh::Director::Models::Instance.make(uuid: 'a-uuid', index: 0, job: 'job_name', bootstrap: true),
        )
        bootstrap_instance
      end

      let(:bootstrap_instance_plan) do
        InstancePlan.new(
          existing_instance: bootstrap_instance.model,
          desired_instance: desired_instance,
          instance: bootstrap_instance,
          network_plans: [],
          variables_interpolator: variables_interpolator,
        )
      end

      context 'when there are multiple instance plans' do
        let(:az_2) { AvailabilityZone.new('az2_name', {}) }
        let(:instance_in_bootstrap_az) do
          instance = Instance.create_from_instance_group(instance_group, 4, 'started', deployment_model, {}, bootstrap_az, logger, variables_interpolator)
          instance.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: 'bb-uuid1', index: 4, job: 'job_name'))
          instance
        end

        let(:instance_plan_in_bootstrap_az) do
          InstancePlan.new(
            existing_instance: instance_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance_in_bootstrap_az,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )
        end

        let(:instance2_in_bootstrap_az) do
          instance2_in_bootstrap_az = Instance.create_from_instance_group(
            instance_group, 2, 'started', deployment_model, {}, bootstrap_az, logger, variables_interpolator
          )
          instance2_in_bootstrap_az.bind_existing_instance_model(
            Bosh::Director::Models::Instance.make(uuid: 'bb-uuid2', index: 2, job: 'job_name'),
          )
          instance2_in_bootstrap_az
        end

        let(:instance_plan2_in_bootstrap_az) do
          InstancePlan.new(
            existing_instance: instance2_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_in_bootstrap_az,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should put the bootstrap node first' do
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan_in_bootstrap_az, bootstrap_instance_plan])
          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az])
        end

        it 'should sort instance plans in alphanum in the same az' do
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])
          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_in_bootstrap_az])
        end

        it 'should sort instance plans in alphanum order in alphanum sorted az' do
          instance2_not_in_bootstrap_az = Instance.create_from_instance_group(instance_group, 2, 'started', deployment_model, {}, az_2, logger, variables_interpolator)
          instance2_not_in_bootstrap_az.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
          instance_plan2_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance2_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_not_in_bootstrap_az,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_not_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])

          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_not_in_bootstrap_az])
        end

        it 'should set instance plans from az with bootstrap node first' do
          instance2_not_in_bootstrap_az = Instance.create_from_instance_group(instance_group, 2, 'started', deployment_model, {}, az_2, logger, variables_interpolator)
          instance2_not_in_bootstrap_az.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
          instance_plan2_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance2_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance2_not_in_bootstrap_az,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )

          instance3_not_in_bootstrap_az = Instance.create_from_instance_group(instance_group, 3, 'started', deployment_model, {}, az_2, logger, variables_interpolator)
          instance3_not_in_bootstrap_az.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '2-uuid2', index: 3, job: 'job_name'))
          instance_plan3_not_in_bootstrap_az = InstancePlan.new(
            existing_instance: instance3_not_in_bootstrap_az.model,
            desired_instance: desired_instance,
            instance: instance3_not_in_bootstrap_az,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )
          sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_not_in_bootstrap_az, instance_plan3_not_in_bootstrap_az, instance_plan_in_bootstrap_az, bootstrap_instance_plan])

          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan_in_bootstrap_az, instance_plan2_not_in_bootstrap_az, instance_plan3_not_in_bootstrap_az])
        end

        it 'should sort instance plans in multiple azs' do
          az3 = AvailabilityZone.new('az3_name', {})
          az_4 = AvailabilityZone.new('az4_name', {})

          instance4_az3 = Instance.create_from_instance_group(instance_group, 7, 'started', deployment_model, {}, az3, logger, variables_interpolator)
          instance4_az3.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '1234-uuid2', index: 7, job: 'job_name'))
          instance_plan3_az3 = InstancePlan.new(
            existing_instance: instance4_az3.model,
            desired_instance: desired_instance,
            instance: instance4_az3,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )

          instance5_az4 = Instance.create_from_instance_group(instance_group, 8, 'started', deployment_model, {}, az_4, logger, variables_interpolator)
          instance5_az4.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '42341-uuid2', index: 8, job: 'job_name'))
          instance_plan5_az4 = InstancePlan.new(
            existing_instance: instance5_az4.model,
            desired_instance: desired_instance,
            instance: instance5_az4,
            network_plans: [],
            variables_interpolator: variables_interpolator,
          )

          sorted_instance_plans = instance_plan_sorter.sort([bootstrap_instance_plan, instance_plan5_az4, instance_plan3_az3])

          expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan3_az3, instance_plan5_az4])
        end

        context 'when instance does not have az' do
          it 'should sort it without errors' do
            instance2_without_az = Instance.create_from_instance_group(instance_group, 2, 'started', deployment_model, {}, nil, logger, variables_interpolator)
            instance2_without_az.bind_existing_instance_model(Bosh::Director::Models::Instance.make(uuid: '1-uuid2', index: 2, job: 'job_name'))
            instance_plan2_without_az = InstancePlan.new(
              existing_instance: instance2_without_az.model,
              desired_instance: desired_instance,
              instance: instance2_without_az,
              network_plans: [],
              variables_interpolator: variables_interpolator,
            )
            sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_without_az, bootstrap_instance_plan])

            expect(sorted_instance_plans).to eq([bootstrap_instance_plan, instance_plan2_without_az])
          end
        end

        context 'when there is no bootstrap node' do
          it 'should sort the rest of the instance plans successfully' do
            sorted_instance_plans = instance_plan_sorter.sort([instance_plan2_in_bootstrap_az, instance_plan_in_bootstrap_az])
            expect(sorted_instance_plans).to eq([instance_plan_in_bootstrap_az, instance_plan2_in_bootstrap_az])
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
