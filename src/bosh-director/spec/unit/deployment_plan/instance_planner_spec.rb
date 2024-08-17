require 'spec_helper'
require 'json'
require 'ipaddr'

describe 'Bosh::Director::DeploymentPlan::InstancePlanner' do
  include Bosh::Director::IpUtil

  subject(:instance_planner) { Bosh::Director::DeploymentPlan::InstancePlanner.new(instance_plan_factory, logger) }

  let(:instance_plan_factory) do
    Bosh::Director::DeploymentPlan::InstancePlanFactory.new(
      instance_repo,
      {},
      deployment,
      index_assigner,
      variables_interpolator,
      [],
      options,
    )
  end

  let(:index_assigner) { Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner.new(deployment_model) }
  let(:options) { {} }
  let(:skip_drain_decider) { Bosh::Director::DeploymentPlan::AlwaysSkipDrain.new }
  let(:logger) { instance_double(Logger, debug: nil, info: nil) }
  let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }
  let(:instance_repo) { Bosh::Director::DeploymentPlan::InstanceRepository.new(logger, variables_interpolator) }
  let(:networks) { [] }
  let(:instance_states) { {} }
  let(:availability_zones) { [az] }

  let(:deployment) do
    instance_double(
      Bosh::Director::DeploymentPlan::Planner,
      model: deployment_model,
      networks: networks,
      skip_drain: skip_drain_decider,
    )
  end

  let(:deployment_model) { FactoryBot.create(:models_deployment) }
  let(:variable_set_model) { Bosh::Director::Models::VariableSet.create(deployment: deployment_model) }
  let(:az) do
    Bosh::Director::DeploymentPlan::AvailabilityZone.new(
      'foo-az',
      'some-cloud-property' => 'foo',
    )
  end
  let(:undesired_az) do
    Bosh::Director::DeploymentPlan::AvailabilityZone.new(
      'old-az',
      'some-cloud-property' => 'foo',
    )
  end

  let(:instance_group) do
    FactoryBot.build(:deployment_plan_instance_group,
      name: 'foo-instance_group',
      availability_zones: availability_zones,
      instance_states: instance_states,
    )
  end

  let(:desired_instance) { Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment) }
  let(:tracer_instance) { make_instance }
  let(:vm_resources_cache) { instance_double(Bosh::Director::DeploymentPlan::VmResourcesCache) }

  before do
    allow(deployment_model).to receive(:current_variable_set).and_return(variable_set_model)
  end

  def make_instance(idx = 0)
    Bosh::Director::DeploymentPlan::Instance.create_from_instance_group(
      instance_group,
      idx,
      'started',
      deployment_model,
      {},
      az,
      logger,
      variables_interpolator,
    ).tap do |i|
      i.bind_new_instance_model
    end
  end

  def make_instance_with_existing_model(existing_instance_model)
    Bosh::Director::DeploymentPlan::Instance.create_from_instance_group(
      instance_group,
      existing_instance_model.index,
      'started',
      deployment_model,
      {},
      az,
      logger,
      variables_interpolator,
    ).tap do |i|
      i.bind_existing_instance_model(existing_instance_model)
    end
  end

  describe 'plan_instance_group_instances' do
    before do
      allow(instance_group).to receive(:networks).and_return([])
    end

    it 'creates instance plans for existing instances' do
      existing_instance_model = FactoryBot.create(:models_instance,
        job: 'foo-instance_group',
        index: 0,
        availability_zone: az.name,
        variable_set: variable_set_model,
      )

      allow(instance_repo).to receive(:fetch_existing).with(
        existing_instance_model,
        nil,
        desired_instance,
      ).and_return(tracer_instance)

      instance_plans = instance_planner.plan_instance_group_instances(
        instance_group,
        [desired_instance],
        [existing_instance_model],
        vm_resources_cache,
      )

      expect(instance_plans.count).to eq(1)
      existing_instance_plan = instance_plans.first

      expected_desired_instance =
        Bosh::Director::DeploymentPlan::DesiredInstance.new(
          instance_group,
          deployment,
          az,
          0,
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
      existing_instance_model = FactoryBot.create(:models_instance,
        job: 'foo-instance_group',
        index: 0,
        availability_zone: az.name,
        variable_set: variable_set_model,
      )
      allow(instance_repo).to receive(:fetch_existing).with(
        existing_instance_model,
        nil,
        desired_instance,
      ).and_return(tracer_instance)
      expect(tracer_instance).to receive(:update_description)

      instance_planner.plan_instance_group_instances(
        instance_group,
        [desired_instance],
        [existing_instance_model],
        vm_resources_cache,
      )
    end

    it 'creates instance plans for new instances' do
      existing_instances = []
      allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }

      instance_plans = instance_planner.plan_instance_group_instances(
        instance_group,
        [desired_instance],
        existing_instances,
        vm_resources_cache,
      )

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

      desired_existing_instance_model = FactoryBot.create(:models_instance,
        job: 'foo-instance_group',
        index: out_of_typical_range_index,
        availability_zone: az.name,
        variable_set: variable_set_model,
      )

      other_desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(
        instance_group,
        deployment,
        az,
        out_of_typical_range_index,
      )

      desired_instances = [
        desired_instance,
        other_desired_instance,
      ]

      undesired_existing_instance_model = FactoryBot.create(:models_instance,
        job: 'foo-instance_group',
        index: auto_picked_index,
        availability_zone: undesired_az.name,
        variable_set: variable_set_model,
      )
      existing_instances = [undesired_existing_instance_model, desired_existing_instance_model]
      allow(instance_repo).to receive(:fetch_existing).with(
        desired_existing_instance_model,
        nil,
        other_desired_instance,
      ) do
        make_instance(out_of_typical_range_index)
      end

      allow(instance_repo).to receive(:create).with(desired_instances[1], 0) { make_instance(auto_picked_index) }

      instance_plans = instance_planner.plan_instance_group_instances(
        instance_group,
        desired_instances,
        existing_instances,
        vm_resources_cache,
      )
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

    context 'when instance should skip running drain script' do
      let(:skip_drain_decider) { Bosh::Director::DeploymentPlan::SkipDrain.new('*') }

      it 'should set "skip_drain" on the instance plan' do
        existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, availability_zone: az.name)
        instance_plans = instance_planner.plan_instance_group_instances(
          instance_group,
          [desired_instance],
          [existing_instance_model],
          vm_resources_cache,
        )
        expect(instance_plans.select(&:skip_drain).count).to eq(instance_plans.count)
      end
    end

    context 'when deployment is being recreated' do
      let(:options) do
        { 'recreate' => true }
      end

      it 'should return instance plans with "recreate" option set on them' do
        existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, availability_zone: az.name)

        instance_plans = instance_planner.plan_instance_group_instances(
          instance_group,
          [desired_instance],
          [existing_instance_model],
          vm_resources_cache,
        )

        expect(instance_plans.select(&:recreate_deployment).count).to eq(instance_plans.count)
      end
    end

    context 'when there are ignored instances' do
      let(:instance_states) { { '0' => 'stopped' } }

      it 'fails if specifically changing the state of ignored vms' do
        existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, ignore: true)
        expect do
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model], vm_resources_cache)
        end.to raise_error(
          Bosh::Director::JobInstanceIgnored,
          "You are trying to change the state of the ignored instance 'foo-instance_group/#{existing_instance_model.uuid}'. " \
            'This operation is not allowed. You need to unignore it first.',
        )
      end
    end

    context 'when instance_group has no az' do
      let(:availability_zones) { [] }

      it 'creates instance plans for new instances with no az' do
        existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0)

        allow(instance_repo).to receive(:fetch_existing).with(existing_instance_model, nil, desired_instance) { tracer_instance }

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model], vm_resources_cache)

        expect(instance_plans.count).to eq(1)
        existing_instance_plan = instance_plans.first

        expected_desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment)
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

    context 'logging active vm presence' do
      context 'when instance has active vm' do
        it 'logs that theres is a vm' do
          existing_instance_model =
            FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, availability_zone: az.name).tap do |i|
              i.active_vm = FactoryBot.create(:models_vm, instance: i)
            end


          expect(logger).to receive(:info).with("Existing desired instance '#{existing_instance_model.job}/#{existing_instance_model.index}' in az '#{az.name}' with active vm")
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model], vm_resources_cache)
        end
      end

      context 'when instance has active vm' do
        it 'logs that theres is no active vm' do
          existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, availability_zone: az.name)

          expect(logger).to receive(:info).with("Existing desired instance '#{existing_instance_model.job}/#{existing_instance_model.index}' in az '#{az.name}' with no active vm")
          instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [existing_instance_model], vm_resources_cache)
        end
      end
    end

    context 'moving an instance to a different az' do
      it "should not attempt to reuse the existing instance's index" do
        existing_instance_model = FactoryBot.create(:models_instance,
          job: 'foo-instance_group',
          index: 0,
          availability_zone: undesired_az.name,
          deployment: deployment_model,
          variable_set: variable_set_model,
        )
        another_existing_instance_model = FactoryBot.create(:models_instance,
          job: 'foo-instance_group',
          index: 1,
          availability_zone: undesired_az.name,
          deployment: deployment_model,
          variable_set: variable_set_model,
        )
        existing_instances = [existing_instance_model, another_existing_instance_model]

        desired_instances = [desired_instance]
        expected_new_instance_index = 2
        allow(instance_repo).to receive(:create).with(desired_instances[0], expected_new_instance_index) { make_instance(2) }

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, desired_instances, existing_instances, vm_resources_cache)

        expect(instance_plans.count).to eq(3)
        obsolete_instance_plans = instance_plans.select(&:obsolete?)
        expect(obsolete_instance_plans.map(&:existing_instance)).to eq(
          [existing_instance_model, another_existing_instance_model],
        )

        new_instance_plan = instance_plans.find(&:new?)
        expect(new_instance_plan.new?).to eq(true)
        expect(new_instance_plan.obsolete?).to eq(false)
      end
    end

    context 'when vm requirements are given' do
      let(:instance_group) do
        vm_resources = Bosh::Director::DeploymentPlan::VmResources.new('cpu' => 4, 'ram' => 2048, 'ephemeral_disk_size' => 100)
        FactoryBot.build(:deployment_plan_instance_group,
          name: 'foo-instance_group',
          vm_resources: vm_resources,
          availability_zones: availability_zones,
        )
      end

      it 'updates the cloud properties with the vm requirements retrieved via the CPI' do
        existing_instances = []
        allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }
        allow(vm_resources_cache).to receive(:get_vm_cloud_properties).and_return('vm_resources' => 'foo')

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], existing_instances, vm_resources_cache)

        expect(vm_resources_cache).to have_received(:get_vm_cloud_properties).once
        expect(instance_plans.first.instance.cloud_properties).to include('vm_resources' => 'foo')
      end

      it 'does not update the cloud properties if planned instance is obsolete' do
        existing_instances = [FactoryBot.create(:models_instance, job: 'foo-instance-group', index: 0)]
        desired_instances = []
        allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }
        allow(vm_resources_cache).to receive(:get_vm_cloud_properties).and_return('vm_resources' => 'foo')

        instance_plans = instance_planner.plan_instance_group_instances(instance_group, desired_instances, existing_instances, vm_resources_cache)

        expect(vm_resources_cache).to_not have_received(:get_vm_cloud_properties)
        expect(instance_plans.first.instance.cloud_properties).to_not include('vm_resources' => 'foo')
      end
    end

    context 'resolving bootstrap nodes' do
      context 'when existing instance is marked as bootstrap' do
        it 'keeps bootstrap node' do
          existing_instance_model = FactoryBot.create(:models_instance,
            job: 'foo-instance_group',
            index: 0,
            bootstrap: true,
            availability_zone: az.name,
            variable_set: variable_set_model,
          )

          existing_tracer_instance = make_instance_with_existing_model(existing_instance_model)
          allow(instance_repo).to receive(:fetch_existing)
            .with(existing_instance_model, nil, desired_instance) { existing_tracer_instance }

          instance_plans = instance_planner.plan_instance_group_instances(
            instance_group,
            [desired_instance],
            [existing_instance_model],
            vm_resources_cache,
          )

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
          existing_instance_model = FactoryBot.create(:models_instance,
            job: 'foo-instance_group',
            index: 0,
            bootstrap: true,
            availability_zone: undesired_az.name,
            deployment: deployment_model,
            variable_set: variable_set_model,
          )
          another_existing_instance_model = FactoryBot.create(:models_instance,
            job: 'foo-instance_group',
            index: 1,
            availability_zone: az.name,
            deployment: deployment_model,
            variable_set: variable_set_model,
          )
          another_desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 1)

          existing_tracer_instance = make_instance_with_existing_model(existing_instance_model)
          allow(instance_repo).to receive(:fetch_existing)
            .with(another_existing_instance_model, nil, another_desired_instance) { existing_tracer_instance }
          allow(instance_repo).to receive(:create).with(desired_instance, 2) { make_instance(2) }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [another_desired_instance, desired_instance], [existing_instance_model, another_existing_instance_model], vm_resources_cache)

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
          existing_instance_model1 = FactoryBot.create(:models_instance,
            job: 'foo-instance_group-z1',
            index: 0,
            bootstrap: true,
            availability_zone: az.name,
            variable_set: variable_set_model,
          )
          desired_instance1 = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 0)

          existing_instance_model2 = FactoryBot.create(:models_instance, 
            job: 'foo-instance_group-z2',
            index: 0,
            bootstrap: true,
            availability_zone: az.name,
            variable_set: variable_set_model,
          )
          desired_instance2 = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment, az, 1)

          allow(instance_repo).to receive(:fetch_existing)
            .with(existing_instance_model1, nil, desired_instance1) { make_instance(0) }
          allow(instance_repo).to receive(:fetch_existing)
            .with(existing_instance_model2, nil, desired_instance2) { make_instance(1) }

          instance_plans = instance_planner.plan_instance_group_instances(
            instance_group,
            [desired_instance1, desired_instance2],
            [existing_instance_model1, existing_instance_model2],
            vm_resources_cache,
          )

          expect(instance_plans.count).to eq(2)
          bootstrap_instance_plans = instance_plans.select { |ip| ip.instance.bootstrap? }
          expect(bootstrap_instance_plans.size).to eq(1)
          expect(bootstrap_instance_plans.first.desired_instance.index).to eq(0)
        end
      end

      context 'when there are no bootstrap instances' do
        it 'assigns the instance with the lowest index as bootstrap instance' do
          existing_instances = []
          another_desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group)

          allow(instance_repo).to receive(:create).with(desired_instance, 0) { tracer_instance }

          allow(instance_repo).to receive(:create).with(another_desired_instance, 1) { make_instance(1) }

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance, another_desired_instance], existing_instances, vm_resources_cache)

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
          existing_instance_model = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0, bootstrap: true, availability_zone: undesired_az.name)

          obsolete_instance = instance_double(Bosh::Director::DeploymentPlan::Instance, update_description: nil)

          instance_plans = instance_planner.plan_instance_group_instances(instance_group, [], [existing_instance_model], vm_resources_cache)

          expect(instance_plans.count).to eq(1)
          obsolete_instance_plan = instance_plans.first

          expect(obsolete_instance_plan.obsolete?).to be_truthy
        end
      end
    end

    context 'when instance has vip networks' do
      let(:vip_network) { Bosh::Director::DeploymentPlan::VipNetwork.parse({ 'name' => 'fake-network' }, [], logger) }

      before do
        instance_group_network =
          FactoryBot.build(:deployment_plan_job_network,
                           name: 'fake-network',
                           static_ips: ['68.68.68.68'],
                           deployment_network: vip_network,
          )
        allow(instance_group).to receive(:networks).and_return([instance_group_network])
      end

      it 'creates network plan for vip network' do
        instance_plans = instance_planner.plan_instance_group_instances(instance_group, [desired_instance], [], vm_resources_cache)

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
      existing_instance_thats_desired = FactoryBot.create(:models_instance, job: 'foo-instance_group', index: 0)
      existing_instance_thats_obsolete = FactoryBot.create(:models_instance, job: 'bar-instance_group', index: 1)

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
      existing_instance_thats_desired = FactoryBot.create(:models_instance, job: 'foo-instance-group', index: 0)
      existing_instance_thats_obsolete = FactoryBot.create(:models_instance, job: 'bar-instance-group', index: 1, ignore: true)

      existing_instances = [existing_instance_thats_desired, existing_instance_thats_obsolete]

      expect do
        instance_planner.plan_obsolete_instance_groups([instance_group], existing_instances)
      end.to raise_error(
        Bosh::Director::DeploymentIgnoredInstancesDeletion,
        "You are trying to delete instance group 'bar-instance-group', " \
        'which contains ignored instance(s). Operation not allowed.',
      )
    end
  end

  describe 'orphan_unreusable_vms' do
    let(:instance_group) do
      vm_type = Bosh::Director::DeploymentPlan::VmType.new(
        'name' => 'a',
        'cloud_properties' => uninterpolated_cloud_properties_hash,
      )

      FactoryBot.build(:deployment_plan_instance_group,
        name: 'foo-instance_group',
        availability_zones: availability_zones,
        env: Bosh::Director::DeploymentPlan::Env.new('env' => 'env-val'),
        vm_type: vm_type,
      )
    end

    let(:uninterpolated_cloud_properties_hash) do
      { 'cloud' => '((interpolated_prop))' }
    end

    let(:existing_instance_model) do
      FactoryBot.create(:models_instance, 
        job: 'foo-instance_group',
        index: 0,
        availability_zone: az.name,
      )
    end

    let(:existing_instance_models) { [existing_instance_model] }

    let(:instance_plans) { [instance_plan, obsolete_instance_plan] }
    let(:instance_plan) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan, obsolete?: false) }
    let(:obsolete_instance_plan) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan, obsolete?: true) }

    let(:agent) { instance_double(Bosh::Director::AgentClient) }

    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      allow(Bosh::Director::Config.current_job).to receive(:username).and_return 'fake-username'
      allow(instance_plan).to receive(:vm_matches_plan?).and_return false
      allow(Bosh::Director::AgentClient).to receive(:with_agent_id)
        .with('fake-agent-id', existing_instance_model.name).and_return(agent)
      allow(agent).to receive(:shutdown)
    end

    it 'does NOT orphan active vms' do
      vm = FactoryBot.create(:models_vm,
        instance: existing_instance_model,
        active: true,
      )
      instance_planner.orphan_unreusable_vms(instance_plans, existing_instance_models)

      expect(existing_instance_model.vms).to include(vm)
    end

    it 'does not orphan vms that match the instance plan' do
      vm = FactoryBot.create(:models_vm,
        instance: existing_instance_model,
        active: true,
      )
      usable_vm = FactoryBot.create(:models_vm, instance: existing_instance_model)

      allow(instance_plan).to receive(:vm_matches_plan?).with(usable_vm).and_return true

      instance_planner.orphan_unreusable_vms(instance_plans, existing_instance_models)

      expect(existing_instance_model.vms).to include(vm)
      expect(existing_instance_model.vms).to include(usable_vm)
    end

    it 'short circuits when detecting a matching instance plan for each vm' do
      instance_plan2 = instance_double(Bosh::Director::DeploymentPlan::InstancePlan, obsolete?: false)
      unusable_vm = FactoryBot.create(:models_vm,
        instance: existing_instance_model,
        active: false,
        agent_id: 'fake-agent-id',
      )

      allow(instance_plan).to receive(:vm_matches_plan?).with(unusable_vm).and_return true
      expect(instance_plan).to receive(:vm_matches_plan?).once
      expect(instance_plan2).not_to receive(:vm_matches_plan?)

      instance_plans = [instance_plan, instance_plan2]
      instance_planner.orphan_unreusable_vms(instance_plans, existing_instance_models)
    end

    it 'orphans VMs that do not match' do
      vm = FactoryBot.create(:models_vm,
        instance: existing_instance_model,
        active: true,
      )
      unusable_vm = FactoryBot.create(:models_vm,
        instance: existing_instance_model,
        active: false,
        agent_id: 'fake-agent-id',
      )

      allow(instance_plan).to receive(:vm_matches_plan?).with(unusable_vm).and_return false

      instance_planner.orphan_unreusable_vms(instance_plans, existing_instance_models)

      expect(existing_instance_model.vms).to include(vm)
      expect(existing_instance_model.vms).to_not include(unusable_vm)
    end
  end

  describe 'reconcile_network_plans' do
    let(:existing_instance) { make_instance_with_existing_model(existing_instance_model) }
    let(:existing_instance_model) do
      FactoryBot.create(:models_instance, 
        job: 'foo-instance_group',
        index: 0,
        bootstrap: true,
        availability_zone: az.name,
      )
    end

    before do
      Bosh::Director::Models::IpAddress.make(
        address_str: ip_to_i('192.168.1.5').to_s,
        network_name: 'fake-network',
        instance: existing_instance_model,
      )

      allow(deployment).to receive(:network).with('fake-network') { manual_network }

      ip_repo = Bosh::Director::DeploymentPlan::IpRepo.new(logger)
      ip_provider = Bosh::Director::DeploymentPlan::IpProvider.new(
        ip_repo,
        { 'fake-network' => manual_network },
        logger,
      )
      allow(deployment).to receive(:ip_provider) { ip_provider }
      fake_job
    end

    let(:manual_network) { Bosh::Director::DeploymentPlan::ManualNetwork.new('fake-network', [subnet], logger) }
    let(:subnet) do
      Bosh::Director::DeploymentPlan::ManualNetworkSubnet.new(
        'fake-network',
        IPAddr.new('192.168.1.0/24'),
        nil, nil, nil, nil, ['foo-az'], [],
        []
      )
    end

    it 'marks undesired existing network reservations as obsolete' do
      instance_plans = instance_planner.plan_instance_group_instances(
        instance_group,
        [desired_instance],
        [existing_instance_model],
        vm_resources_cache,
      )
      instance_planner.reconcile_network_plans(instance_plans)

      expect(instance_plans.count).to eq(1)
      existing_instance_plan = instance_plans.first
      expect(existing_instance_plan.network_plans.first.obsolete?).to be_truthy
    end

    context 'when network reservation is needed' do
      let(:networks) { [manual_network] }

      before do
        instance_group_network =
          FactoryBot.build(:deployment_plan_job_network,
                           static_ips: nil,
                           deployment_network: manual_network,
          )
        allow(instance_group).to receive(:networks).and_return([instance_group_network])
      end

      it 'marks desired existing reservations as existing' do
        instance_plans = instance_planner.plan_instance_group_instances(
          instance_group,
          [desired_instance],
          [existing_instance_model],
          vm_resources_cache,
        )
        instance_planner.reconcile_network_plans(instance_plans)

        expect(instance_plans.count).to eq(1)
        existing_instance_plan = instance_plans.first
        expect(existing_instance_plan.network_plans.first.existing?).to be_truthy
      end
    end
  end
end
