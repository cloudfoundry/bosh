require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::StateApplier do
    include Support::StemcellHelpers

    subject(:state_applier) do
      InstanceUpdater::StateApplier.new(instance_plan, agent_client, rendered_job_templates_cleaner, logger, options)
    end

    let(:task) { instance_double('Bosh::Director::EventLog::Task') }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:options) do
      { task: task }
    end
    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        desired_instance: DeploymentPlan::DesiredInstance.new(instance_group),
        instance: instance,
        variables_interpolator: variables_interpolator,
      )
    end

    let(:network_spec) do
      { 'name' => 'default', 'subnets' => [{ 'cloud_properties' => { 'foo' => 'bar' }, 'az' => 'foo-az' }] }
    end
    let(:network) { DeploymentPlan::DynamicNetwork.parse(network_spec, [availability_zone], logger) }

    let(:instance_group) do
      instance_double(
        'Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'fake-job',
        spec: { 'name' => 'job' },
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: { 'gateway' => 'default' },
        vm_type: DeploymentPlan::VmType.new('name' => 'fake-vm-type'),
        vm_extensions: [],
        stemcell: make_stemcell(name: 'fake-stemcell-name', version: '1.0'),
        env: DeploymentPlan::Env.new('key' => 'value'),
        package_spec: {},
        persistent_disk_collection: DeploymentPlan::PersistentDiskCollection.new(logger),
        errand?: false,
        compilation?: false,
        jobs: [],
        update_spec: update_config.to_hash,
        properties: {},
        vm_resources: DeploymentPlan::VmResources.new('cpu' => 1, 'ephemeral_disk_size' => 1, 'ram' => 1),
        lifecycle: DeploymentPlan::InstanceGroup::DEFAULT_LIFECYCLE_PROFILE,
        vm_strategy: 'fake-strat',
      )
    end
    let(:update_config) do
      DeploymentPlan::UpdateConfig.new(
        'canaries' => 1,
        'max_in_flight' => 1,
        'canary_watch_time' => '1000-2000',
        'update_watch_time' => update_watch_time,
      )
    end
    let(:deployment) { FactoryBot.create(:models_deployment, name: 'fake-deployment') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', 'a' => 'b') }
    let(:instance) do
      DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        0,
        instance_state,
        deployment,
        {},
        availability_zone,
        logger,
        variables_interpolator,
      )
    end
    let(:instance_model) { Models::Instance.make(deployment: deployment, state: instance_model_state, uuid: 'uuid-1') }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:rendered_job_templates_cleaner) { instance_double(RenderedJobTemplatesCleaner) }
    let(:instance_state) { 'started' }
    let(:instance_model_state) { 'stopped' }
    let(:job_state) { 'running' }
    let(:update_watch_time) { '1000-2000' }

    before do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
      reservation.resolve_ip('192.168.0.10')

      instance_plan.network_plans << DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
      instance.bind_existing_instance_model(instance_model)

      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      App.new(config)

      allow(AgentClient).to receive(:with_agent_id).with(instance_model.agent_id, instance_model.name).and_return(agent_client)
      allow(agent_client).to receive(:apply)
      allow(rendered_job_templates_cleaner).to receive(:clean)
      allow(state_applier).to receive(:sleep)
      allow(Starter).to receive(:start)
      allow(task).to receive(:advance).with(10, status: 'installing packages')
      allow(task).to receive(:advance).with(10, status: 'configuring jobs')
    end

    it 'starts the instance' do
      state_applier.apply(update_config)
      expect(Starter).to have_received(:start).with(
        instance: instance,
        agent_client: agent_client,
        update_config: update_config,
        is_canary: false,
        wait_for_running: true,
        logger: logger,
        task: task,
      )
    end

    it 'updates instance spec' do
      expect(agent_client).to receive(:apply).with(instance_plan.spec.as_apply_spec)
      state_applier.apply(update_config)
      expect(instance_model.spec).to eq(instance_plan.spec.full_spec)
    end

    it 'can skip post start if wait_for_running is false' do
      state_applier.apply(update_config, false)
      expect(Starter).to have_received(:start).with(
        instance: instance,
        agent_client: agent_client,
        update_config: update_config,
        is_canary: false,
        wait_for_running: false,
        logger: logger,
        task: task,
      )
    end

    it 'cleans rendered templates after applying' do
      expect(agent_client).to receive(:apply).ordered
      expect(rendered_job_templates_cleaner).to receive(:clean).ordered
      state_applier.apply(update_config)
    end

    context 'when not given a event task logger' do
      let(:options) do
        {}
      end

      it 'does not call advance' do
        expect(task).to_not receive(:advance)
        state_applier.apply(update_config)
      end
    end
  end
end
