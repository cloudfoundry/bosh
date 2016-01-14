require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFactory do
      include Bosh::Director::IpUtil

      let(:instance_repo) { nil }
      let(:skip_drain) { SkipDrain.new(true) }
      let(:index_assigner) { nil }
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
      end
    end
  end
end
