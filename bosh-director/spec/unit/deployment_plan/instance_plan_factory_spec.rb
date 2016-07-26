require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFactory do
      include Bosh::Director::IpUtil

      let(:instance_repo) { nil }
      let(:skip_drain) { SkipDrain.new(true) }
      let(:index_assigner) { instance_double(PlacementPlanner::IndexAssigner) }
      let(:network_reservation_repository) { NetworkReservationRepository.new(deployment_plan, logger) }
      let(:existing_instance_model) { Models::Instance.make }
      let(:range) { NetAddr::CIDR.create('192.168.1.1/24') }
      let(:manual_network_subnet) { ManualNetworkSubnet.new('name-7', range, nil, nil, nil, nil, nil, [], []) }
      let(:network) { BD::DeploymentPlan::ManualNetwork.new('name-7', [manual_network_subnet], logger) }
      let(:ip_repo) { BD::DeploymentPlan::InMemoryIpRepo.new(logger) }
      let(:deployment_plan) do
        instance_double(Planner,
          network: network,
          ip_provider: BD::DeploymentPlan::IpProvider.new(ip_repo, {'name-7' => network}, logger)
        )
      end
      let(:existing_instance_model_unresponsive) { Models::Instance.make(job: job) }
      let(:job) do
        job = DeploymentPlan::InstanceGroup.new(logger)
        job.name = 'job-name'
        job
      end

      let(:states_by_existing_instance) do
        {
          existing_instance_model =>
            {
              'networks' =>
                {
                  'name-7' => {
                    'ip' => '192.168.1.1',
                    'type' => 'dynamic'
                  }
                }
            },
          existing_instance_model_unresponsive =>
            {
              'current_state' => 'unresponsive'
            }
        }
      end
      let(:options) { {} }

      subject(:instance_plan_factory) do
        InstancePlanFactory.new(
          instance_repo,
          states_by_existing_instance,
          skip_drain,
          index_assigner,
          network_reservation_repository,
          options)
      end

      context 'obsolete_instance_plan' do
        it 'returns an instance plan with a nil desired instnace' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.desired_instance).to be_nil
        end

        it 'populates the instance plan existing model' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.existing_instance).to eq(existing_instance_model)
        end

        it 'fetches network reservations' do
          instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(ip_repo.contains_ip?(ip_to_i('192.168.1.1'), 'name-7')).to eq(true)
        end

        context 'need_to_fix' do
          context 'when fix parameter is true' do
            let(:options) {
              {'fix' => true}
            }
            it 'will set parameter to recreate instance with unresponsive agent' do
              instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model_unresponsive)
              expect(instance_plan.need_to_fix).to be_truthy
            end

            it 'will not set parameter to recreate running instance' do
              instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
              expect(instance_plan.need_to_fix).to be_falsey
            end
          end

          context 'when fix parameter is false' do
            let(:options) {
              {'fix' => false}
            }
            it 'will not set parameter to recreate instance with unresponsive agent' do
              instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model_unresponsive)
              expect(instance_plan.need_to_fix).to be_falsey
            end
          end
        end
      end

      context 'desired_existing_instance_plan' do
        let(:desired_instance) { DeploymentPlan::DesiredInstance.new(job) }

        let(:instance_repo) do
          instance_double(InstanceRepository,
                          fetch_existing: instance_double(Instance, update_description: nil, model: existing_instance_model_unresponsive))
        end

        context 'need_to_fix' do
          before {
            allow(index_assigner).to receive(:assign_index).with(desired_instance.job.name, existing_instance_model_unresponsive).and_return(0)
          }

          context 'when fix parameter is true' do
            let(:options) {
              {'fix' => true}
            }

            it 'will set parameter to recreate instance with unresponsive agent' do
              instance_plan = instance_plan_factory.desired_existing_instance_plan(existing_instance_model_unresponsive, desired_instance)
              expect(instance_plan.need_to_fix).to be_truthy
            end

            it 'will not set parameter to recreate running instance' do
              allow(index_assigner).to receive(:assign_index).with(desired_instance.job.name, existing_instance_model).and_return(0)
              instance_plan = instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
              expect(instance_plan.need_to_fix).to be_falsey
            end
          end

          context 'when fix parameter is false' do
            let(:options) {
              {'fix' => false}
            }

            it 'will not set parameter to recreate instance with unresponsive agent' do
              instance_plan = instance_plan_factory.desired_existing_instance_plan(existing_instance_model_unresponsive, desired_instance)
              expect(instance_plan.need_to_fix).to be_falsey
            end
          end
        end
      end
    end
  end
end
