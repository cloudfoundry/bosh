require 'spec_helper'

describe 'BD::DeploymentPlan::InstancePlanner' do
  include BD::IpUtil

  subject(:instance_planner) { BD::DeploymentPlan::InstancePlanner.new(instance_plan_factory, logger) }
  let(:network_reservation_repository) { BD::DeploymentPlan::NetworkReservationRepository.new(deployment, logger) }
  let(:instance_plan_factory) { BD::DeploymentPlan::InstancePlanFactory.new(instance_repo, {}, skip_drain_decider, index_assigner, network_reservation_repository, options) }
  let(:index_assigner) { BD::DeploymentPlan::PlacementPlanner::IndexAssigner.new(deployment_model) }
  let(:options) { {} }
  let(:skip_drain_decider) { BD::DeploymentPlan::AlwaysSkipDrain.new }
  let(:logger) { instance_double(Logger, debug: nil, info: nil) }
  let(:instance_repo) { BD::DeploymentPlan::InstanceRepository.new(network_reservation_repository, logger) }
  let(:deployment) { instance_double(BD::DeploymentPlan::Planner, model: deployment_model) }
  let(:deployment_model) { BD::Models::Deployment.make }
  let(:variable_set_model) { BD::Models::VariableSet.create(deployment: deployment_model) }
  let(:az) do
    BD::DeploymentPlan::AvailabilityZone.new(
      'foo-az',
      'cloud_properties' => {}
    )
  end
  let(:undesired_az) do
    BD::DeploymentPlan::AvailabilityZone.new(
      'old-az',
      'cloud_properties' => {}
    )
  end
  let(:instance_group) do
    instance_group = BD::DeploymentPlan::InstanceGroup.new(logger)
    instance_group.name = 'foo-instance_group'
    instance_group.availability_zones << az
    instance_group
  end
  let(:desired_instance) { BD::DeploymentPlan::DesiredInstance.new(instance_group, deployment) }
  let(:tracer_instance) do
    make_instance
  end

  before do
    allow(deployment_model).to receive(:current_variable_set).and_return(variable_set_model)
  end

  def make_instance(idx=0)
    instance = BD::DeploymentPlan::Instance.create_from_job(instance_group, idx, 'started', deployment_model, {}, az, logger)
    instance.bind_new_instance_model
    instance
  end

  def make_instance_with_existing_model(existing_instance_model)
    instance = BD::DeploymentPlan::Instance.create_from_job(instance_group, existing_instance_model.index, 'started', deployment_model, {}, az, logger)
    instance.bind_existing_instance_model(existing_instance_model)
    instance
  end

  describe 'plan_instance_group_instances' do
    before do
      allow(instance_group).to receive(:networks).and_return([])
    end

    context 'when instance should skip running drain script' do
      let(:skip_drain_decider) { BD::DeploymentPlan::SkipDrain.new('*') }

      it 'should set "skip_drain" on the instance plan' do
        existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name)
        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])
        expect(instance_plans.select(&:skip_drain).count).to eq(instance_plans.count)
      end
    end

    context 'when deployment is being recreated' do
      let(:options) { {'recreate' => true} }

      it 'should return instance plans with "recreate" option set on them' do
        existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name)

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

        expect(instance_plans.select(&:recreate_deployment).count).to eq(instance_plans.count)
      end
    end

    context 'when there are ignored instances' do
      it 'fails if specifically changing the state of ignored vms' do
        existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, ignore: true)
        instance_group.instance_states = {'0' => "stopped"}
        expect {
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])
        }.to raise_error(
          Bosh::Director::JobInstanceIgnored,
          "You are trying to change the state of the ignored instance 'foo-instance_group/#{existing_instance_model.uuid}'. " +
              "This operation is not allowed. You need to unignore it first."
        )
      end
    end

    context 'when instance_group has no az' do
      before { instance_group.availability_zones = [] }

      it 'creates instance plans for new instances with no az' do
        existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0)

        allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model, nil, instance_group, 0, deployment) { tracer_instance }

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

        expect(instance_plans.count).to eq(1)
        existing_instance_plan = instance_plans.first

        expected_desired_instance = BD::DeploymentPlan::DesiredInstance.new(
          instance_group,
          deployment,
          nil,
          0
        )
        expect(existing_instance_plan.new?).to eq(false)
        expect(existing_instance_plan.obsolete?).to eq(false)

        expect(existing_instance_plan.desired_instance.instance_group).to eq(expected_desired_instance.instance_group)
        expect(existing_instance_plan.desired_instance.deployment).to eq(expected_desired_instance.deployment)
        expect(existing_instance_plan.desired_instance.az).to eq(expected_desired_instance.az)
        expect(existing_instance_plan.instance.bootstrap?).to eq(true)

        expect(existing_instance_plan.instance).to eq(tracer_instance)
        expect(existing_instance_plan.existing_instance).to eq(existing_instance_model)
      end
    end

    describe 'logging active vm presence' do
      context 'when instance has active vm' do
        it 'logs that theres is a vm' do
          existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name)
          vm = BD::Models::Vm.make(instance: existing_instance_model)
          existing_instance_model.active_vm = vm

          expect(logger).to receive(:info).with("Existing desired instance '#{existing_instance_model.job}/#{existing_instance_model.index}' in az '#{az.name}' with active vm")
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])
        end
      end

      context 'when instance has active vm' do
        it 'logs that theres is no active vm' do
          existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name)

          expect(logger).to receive(:info).with("Existing desired instance '#{existing_instance_model.job}/#{existing_instance_model.index}' in az '#{az.name}' with no active vm")
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])
        end
      end
    end

    describe 'moving an instance to a different az' do
      it "should not attempt to reuse the existing instance's index" do
        existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: undesired_az.name, deployment: deployment_model, :variable_set => variable_set_model)
        another_existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 1, availability_zone: undesired_az.name, deployment: deployment_model, :variable_set => variable_set_model)
        existing_instances = [existing_instance_model, another_existing_instance_model]

        desired_instances = [desired_instance]
        expected_new_instance_index = 2
        allow(instance_repo).to receive(:create).with(desired_instances[0], expected_new_instance_index) { make_instance(2) }

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, desired_instances, existing_instances)

        expect(instance_plans.count).to eq(3)
        obsolete_instance_plans = instance_plans.select(&:obsolete?)
        expect(obsolete_instance_plans.map(&:existing_instance)).to eq(
            [existing_instance_model, another_existing_instance_model])

        new_instance_plan = instance_plans.find(&:new?)
        expect(new_instance_plan.new?).to eq(true)
        expect(new_instance_plan.obsolete?).to eq(false)
      end
    end

    it 'creates instance plans for existing instances' do
      existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name, :variable_set => variable_set_model)

      allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model, nil, instance_group, 0, deployment) { tracer_instance }

      instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

      expect(instance_plans.count).to eq(1)
      existing_instance_plan = instance_plans.first

      expected_desired_instance = BD::DeploymentPlan::DesiredInstance.new(
        instance_group,
        deployment,
        az,
        0
      )
      expect(existing_instance_plan.new?).to eq(false)
      expect(existing_instance_plan.obsolete?).to eq(false)

      expect(existing_instance_plan.desired_instance.instance_group).to eq(expected_desired_instance.instance_group)
      expect(existing_instance_plan.desired_instance.deployment).to eq(expected_desired_instance.deployment)
      expect(existing_instance_plan.desired_instance.az).to eq(expected_desired_instance.az)
      expect(existing_instance_plan.instance.bootstrap?).to eq(true)

      expect(existing_instance_plan.instance).to eq(tracer_instance)
      expect(existing_instance_plan.existing_instance).to eq(existing_instance_model)
    end

    it 'updates descriptions for existing instances' do
      existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, availability_zone: az.name, :variable_set => variable_set_model)
      allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model, nil, instance_group, 0, deployment) { tracer_instance }
      expect(tracer_instance).to receive(:update_description)

      instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])
    end

    it 'creates instance plans for new instances' do
      existing_instances = []
      allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }

      instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], existing_instances)

      expect(instance_plans.count).to eq(1)
      new_instance_plan = instance_plans.first

      expect(new_instance_plan.new?).to eq(true)
      expect(new_instance_plan.obsolete?).to eq(false)
      expect(new_instance_plan.desired_instance).to eq(desired_instance)
      expect(new_instance_plan.instance).to eq(tracer_instance)
      expect(new_instance_plan.existing_instance).to be_nil
      expect(new_instance_plan).to be_new
    end

    it 'creates instance plans for new, existing and obsolete instances' do
      out_of_typical_range_index = 77
      auto_picked_index = 0

      desired_existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: out_of_typical_range_index, availability_zone: az.name, :variable_set => variable_set_model)

      desired_instances = [desired_instance, BD::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, out_of_typical_range_index)]

      undesired_existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: auto_picked_index, availability_zone: undesired_az.name, :variable_set => variable_set_model)
      existing_instances = [undesired_existing_instance_model, desired_existing_instance_model]
      allow(instance_repo).to receive(:fetch_existing).with(desired_existing_instance_model, nil, instance_group, out_of_typical_range_index, deployment) do
        make_instance(out_of_typical_range_index)
      end

      allow(instance_repo).to receive(:create).with(desired_instances[1], 0) { make_instance(auto_picked_index) }

      instance_plans = instance_planner.plan_instance_group_instances(instance_group, desired_instances, existing_instances)
      expect(instance_plans.count).to eq(3)

      obsolete_instance_plan = instance_plans.find(&:obsolete?)
      expect(obsolete_instance_plan.new?).to eq(false)
      expect(obsolete_instance_plan.obsolete?).to eq(true)
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(undesired_existing_instance_model)
      expect(obsolete_instance_plan.instance).not_to be_nil

      existing_instance_plan = instance_plans.find(&:existing?)
      expect(existing_instance_plan.new?).to eq(false)
      expect(existing_instance_plan.obsolete?).to eq(false)

      new_instance_plan = instance_plans.find(&:new?)
      expect(new_instance_plan.new?).to eq(true)
      expect(new_instance_plan.obsolete?).to eq(false)
    end

    context 'resolving bootstrap nodes' do
      context 'when existing instance is marked as bootstrap' do
        it 'keeps bootstrap node' do
          existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, bootstrap: true, availability_zone: az.name, :variable_set => variable_set_model)

          existing_tracer_instance = make_instance_with_existing_model(existing_instance_model)
          allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model, nil, instance_group, 0, deployment) { existing_tracer_instance }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

          expect(instance_plans.count).to eq(1)
          existing_instance_plan = instance_plans.first

          expect(existing_instance_plan.new?).to be_falsey
          expect(existing_instance_plan.obsolete?).to be_falsey
          expect(existing_instance_plan.instance).to eq(existing_tracer_instance)
          expect(existing_instance_plan.instance.bootstrap?).to be_truthy
        end
      end

      context 'when obsolete instance is marked as bootstrap' do
        it 'picks the lowest indexed instance as new bootstrap instance' do
          existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, bootstrap: true, availability_zone: undesired_az.name, deployment: deployment_model, :variable_set => variable_set_model)
          another_existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 1, availability_zone: az.name, deployment: deployment_model, :variable_set => variable_set_model)
          another_desired_instance = BD::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 1)

          existing_tracer_instance = make_instance_with_existing_model(existing_instance_model)
          allow(instance_repo).to receive(:fetch_existing).with(another_existing_instance_model, nil, instance_group, another_desired_instance.index, deployment) { existing_tracer_instance }
          allow(instance_repo).to receive(:create).with(desired_instance, 2) { make_instance(2) }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [another_desired_instance, desired_instance], [existing_instance_model, another_existing_instance_model])

          expect(instance_plans.count).to eq(3)
          desired_existing_instance_plan = instance_plans.find(&:existing?)
          desired_new_instance_plan = instance_plans.find(&:new?)
          obsolete_instance_plans = instance_plans.select(&:obsolete?)

          expect(obsolete_instance_plans.size).to eq(1)
          expect(desired_existing_instance_plan.instance).to eq(existing_tracer_instance)
          expect(desired_existing_instance_plan.instance.bootstrap?).to be_truthy
          expect(desired_new_instance_plan.instance.bootstrap?).to be_falsey
        end
      end

      context 'when several existing instances are marked as bootstrap' do
        it 'picks the lowest indexed instance as new bootstrap instance' do
          existing_instance_model_1 = BD::Models::Instance.make(job: 'foo-instance_group-z1', index: 0, bootstrap: true, availability_zone: az.name, :variable_set => variable_set_model)
          desired_instance_1 = BD::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 0)
          existing_instance_model_2 = BD::Models::Instance.make(job: 'foo-instance_group-z2', index: 0, bootstrap: true, availability_zone: az.name, :variable_set => variable_set_model)
          desired_instance_2 = BD::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 1)

          allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model_1, nil, instance_group, desired_instance_1.index, deployment) { make_instance(0) }
          allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model_2, nil, instance_group, desired_instance_2.index, deployment) { make_instance(1) }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance_1, desired_instance_2], [existing_instance_model_1, existing_instance_model_2])

          expect(instance_plans.count).to eq(2)
          bootstrap_instance_plans = instance_plans.select { |ip| ip.instance.bootstrap? }
          expect(bootstrap_instance_plans.size).to eq(1)
          expect(bootstrap_instance_plans.first.desired_instance.index).to eq(0)
        end
      end

      context 'when there are no bootstrap instances' do
        it 'assigns the instance with the lowest index as bootstrap instance' do
          existing_instances = []
          another_desired_instance = BD::DeploymentPlan::DesiredInstance.new(instance_group, nil, deployment)

          allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }

          allow(instance_repo).to receive(:create).with(another_desired_instance, 1) { make_instance(1) }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance, another_desired_instance], existing_instances)

          expect(instance_plans.count).to eq(2)
          new_instance_plan = instance_plans.first

          expect(new_instance_plan.new?).to be_truthy
          expect(new_instance_plan.instance.bootstrap?).to be_truthy
          expect(new_instance_plan.instance).to eq(tracer_instance)
          expect(new_instance_plan.existing_instance).to be_nil
        end
      end

      context 'when all instances are obsolete' do
        it 'should not mark any instance as bootstrap instance' do
          existing_instance_model = BD::Models::Instance.make(job: 'foo-instance_group', index: 0, bootstrap: true, availability_zone: undesired_az.name)

          obsolete_instance = instance_double(BD::DeploymentPlan::Instance, update_description: nil)

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [], [existing_instance_model])

          expect(instance_plans.count).to eq(1)
          obsolete_instance_plan = instance_plans.first

          expect(obsolete_instance_plan.obsolete?).to be_truthy
        end
      end
    end

    context 'reconciling network plans' do
      let(:existing_instance) { make_instance_with_existing_model(existing_instance_model) }

      let(:existing_instance_model) { BD::Models::Instance.make(job: 'foo-instance_group', index: 0, bootstrap: true, availability_zone: az.name) }

      before do
        BD::Models::IpAddress.make(address_str: ip_to_i('192.168.1.5').to_s, network_name: 'fake-network', instance: existing_instance_model)

        allow(deployment).to receive(:network).with('fake-network') { manual_network }

        ip_repo = BD::DeploymentPlan::DatabaseIpRepo.new(logger)
        ip_provider = BD::DeploymentPlan::IpProvider.new(ip_repo, {'fake-network' => manual_network}, logger)
        allow(deployment).to receive(:ip_provider) { ip_provider  }
        fake_job
      end

      let(:manual_network) { BD::DeploymentPlan::ManualNetwork.new('fake-network', [subnet], logger) }
      let(:subnet) do
        BD::DeploymentPlan::ManualNetworkSubnet.new(
          'fake-network',
          NetAddr::CIDR.create('192.168.1.0/24'),
          nil, nil, nil, nil, ['foo-az'], [],
          [])
      end

      it 'marks undesired existing network reservations as obsolete' do
        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

        expect(instance_plans.count).to eq(1)
        existing_instance_plan = instance_plans.first
        expect(existing_instance_plan.network_plans.first.obsolete?).to be_truthy
      end

      context 'when network reservation is needed' do
        before do
          instance_group_network = BD::DeploymentPlan::JobNetwork.new('fake-network', nil, [], manual_network)
          allow(instance_group).to receive(:networks).and_return([instance_group_network])
        end

        it 'marks desired existing reservations as existing' do
          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model])

          expect(instance_plans.count).to eq(1)
          existing_instance_plan = instance_plans.first
          expect(existing_instance_plan.network_plans.first.existing?).to be_truthy
        end
      end
    end

    context 'when instance has vip networks' do
      let(:vip_network) { BD::DeploymentPlan::VipNetwork.new({'name' => 'fake-network'}, logger) }
      before do
        instance_group_network = BD::DeploymentPlan::JobNetwork.new('fake-network', ['68.68.68.68'], [], vip_network)
        allow(instance_group).to receive(:networks).and_return([instance_group_network])
      end

      it 'creates network plan for vip network' do
        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [])

        expect(instance_plans.count).to eq(1)
        existing_instance_plan = instance_plans.first
        expect(existing_instance_plan.network_plans.size).to eq(1)
        vip_network_plan = existing_instance_plan.network_plans.first
        expect(vip_network_plan.reservation.network).to eq(vip_network)
        expect(vip_network_plan.reservation.ip).to eq(ip_to_i('68.68.68.68'))
      end
    end
  end

  describe '#plan_obsolete_instance_groups' do
    it 'returns instance plans for each instance_group' do
      existing_instance_thats_desired = BD::Models::Instance.make(job: 'foo-instance_group', index: 0)
      existing_instance_thats_obsolete = BD::Models::Instance.make(job: 'bar-instance_group', index: 1)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]
      instance_plans = instance_planner.plan_obsolete_instance_groups([instance_group], existing_instances)

      expect(instance_plans.count).to eq(1)

      obsolete_instance_plan = instance_plans.first
      expect(obsolete_instance_plan.instance).not_to be_nil
      expect(obsolete_instance_plan.desired_instance).to be_nil
      expect(obsolete_instance_plan.existing_instance).to eq(existing_instance_thats_obsolete)
      expect(obsolete_instance_plan).to be_obsolete
    end

    it 'fails when trying to delete instance groups with ignored instances' do
      existing_instance_thats_desired = BD::Models::Instance.make(job: 'foo-instance-group', index: 0)
      existing_instance_thats_obsolete = BD::Models::Instance.make(job: 'bar-instance-group', index: 1, ignore: true)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]

      expect {
        instance_planner.plan_obsolete_instance_groups([instance_group], existing_instances)
      }.to raise_error(
         Bosh::Director::DeploymentIgnoredInstancesDeletion,
         "You are trying to delete instance group 'bar-instance-group', which contains ignored instance(s). Operation not allowed."
      )
    end
  end
end
