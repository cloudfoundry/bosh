require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFactory do
      include Bosh::Director::IpUtil

      let(:instance_repo) { BD::DeploymentPlan::InstanceRepository.new(network_reservation_repository, logger) }
      let(:skip_drain) { SkipDrain.new(true) }
      let(:index_assigner) { instance_double('Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner') }
      let(:network_reservation_repository) { NetworkReservationRepository.new(deployment_plan, logger) }
      let(:existing_instance_model) do
        Models::Instance.make(
          deployment: deployment_model,
          job: 'foobar',
          index: 0,
          vm_cid: 'vm-cid',
          spec: spec
        )
      end
      let(:spec) do
        {
          'vm_type' => {
            'name' => 'vm-type',
            'cloud_properties' => {'foo' => 'bar'},
          },
          'stemcell' => {
            'name' => 'stemcell-name',
            'version' => '3.0.2'
          },
          'env' => {
            'key1' => 'value1'
          },
          'networks' => {
            'ip' => '192.168.1.1',
          }
        }
      end
      let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.minimal_manifest), :name => 'name-7') }
      let(:range) { NetAddr::CIDR.create('192.168.1.1/24') }
      let(:manual_network_subnet) { ManualNetworkSubnet.new('name-7', range, nil, nil, nil, nil, nil, [], []) }
      let(:network) { BD::DeploymentPlan::ManualNetwork.new('name-7', [manual_network_subnet], logger) }
      let(:ip_repo) { BD::DeploymentPlan::InMemoryIpRepo.new(logger) }
      let(:deployment_plan) do
        instance_double(Planner,
          network: network,
          ip_provider: BD::DeploymentPlan::IpProvider.new(ip_repo, {'name-7' => network}, logger),
          model: deployment_model
        )
      end
      let(:desired_instance) do
        instance_double('Bosh::Director::DeploymentPlan::DesiredInstance')
      end
      let(:instance_group) do
        instance_double('Bosh::Director::DeploymentPlan::InstanceGroup')
      end

      let(:plan_instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance', uuid: 'some-uuid')
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

      before {
        BD::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
        allow(desired_instance).to receive(:instance_group).and_return(instance_group)
        allow(desired_instance).to receive(:index).and_return(1)
        allow(desired_instance).to receive(:index=)
        allow(desired_instance).to receive(:deployment)
        allow(instance_repo).to receive(:create).and_return(plan_instance)
        allow(instance_repo).to receive(:fetch_existing).and_return(plan_instance)
        allow(instance_group).to receive(:name).and_return('group-name')
        allow(index_assigner).to receive(:assign_index)
        allow(plan_instance).to receive(:update_description)
      }

      describe '#obsolete_instance_plan' do
        it 'returns an instance plan with a nil desired instance' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.desired_instance).to be_nil
        end

        it 'populates the instance plan existing model' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.existing_instance).to eq(existing_instance_model)
        end

        it 'ensures it is not recreated' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.needs_recreate?).to be_falsey
        end

        it 'fetches network reservations' do
          instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(ip_repo.contains_ip?(ip_to_i('192.168.1.1'), 'name-7')).to eq(true)
        end
      end

      describe '#desired_existing_instance_plan' do
        let(:tags) { {'key1' => 'value1'} }
        let(:options) { {'tags' => tags} }

        it 'passes tags to instance plan creation' do
          expect(InstancePlan).to receive(:new).with(
            desired_instance: anything,
            existing_instance: anything,
            instance: anything,
            skip_drain: anything,
            recreate_instance: anything,
            need_to_fix: anything,
            tags: tags
          )

          instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
        end

        context 'when some instances need to be recreated' do
          let(:options) { {'recreate' => [existing_instance_model.uuid]} }

          it 'passes through recreate_instance: true to only those instances' do
            allow(instance_repo).to receive(:fetch_existing).and_return(
              instance_double(Instance, uuid: existing_instance_model.uuid, update_description: {}),
              instance_double(Instance, uuid: 'any-uuid', update_description: {}, current_job_state: 'running'))

            plan_to_recreate = instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
            expect(plan_to_recreate.needs_recreate?).to be_truthy

            instance_model = Models::Instance.make
            plan_not_to_recreate = instance_plan_factory.desired_existing_instance_plan(instance_model, desired_instance)
            expect(plan_not_to_recreate.needs_recreate?).to be_falsey
          end
        end
      end

      describe '#desired_new_instance_plan' do
        let(:tags) { {'key1' => 'value1'} }
        let(:options) { {'tags' => tags} }

        it 'passes tags to instance plan creation' do
          expect(InstancePlan).to receive(:new).with(
            desired_instance: anything,
            existing_instance: anything,
            instance: anything,
            skip_drain: anything,
            recreate_instance: anything,
            tags: tags
          )

          instance_plan_factory.desired_new_instance_plan(desired_instance)
        end

        context 'when some instances need to be recreated' do
          let(:options) { {'recreate' => ['recreate-uuid']} }

          it 'passes through recreate_instance: true to only those instances' do
            allow(instance_repo).to receive(:create).and_return(
              instance_double(Instance, uuid: 'recreate-uuid', update_description: {}),
              instance_double(Instance, uuid: 'any-uuid', update_description: {}, current_job_state: 'running'))

            plan_to_recreate = instance_plan_factory.desired_new_instance_plan(desired_instance)
            expect(plan_to_recreate.needs_recreate?).to be_truthy

            plan_not_to_recreate = instance_plan_factory.desired_new_instance_plan(desired_instance)
            expect(plan_not_to_recreate.needs_recreate?).to be_falsey
          end
        end
      end
    end
  end
end
