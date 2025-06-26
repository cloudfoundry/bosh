require 'spec_helper'

RSpec::Matchers.define :log_dns_change do |expected|
  match do |actual|
    allow(actual).to receive(:debug) do |msg|
      parts = msg.scan(%r{local_dns_changed\? changed FROM: (\[.*\]) TO: (\[.*\]) on instance foobar\/fake-uuid-1})
      if parts[0]&.length == 2
        from_msg = ''
        to_msg = ''

        from_msg = JSON.parse(parts[0][0], symbolize_names: true) if parts[0][0] != ''
        to_msg = JSON.parse(parts[0][1], symbolize_names: true) if parts[0][1] != ''

        expect(from_msg).to eq(expected[:from])
        expect(to_msg).to eq(expected[:to])
      end
    end
  end
end

RSpec::Matchers.define :log_persistent_disk_change do |expected|
  match do |actual|
    allow(actual).to receive(:debug) do |msg|
      parts = msg.scan(/persistent_disk_changed\? changed FROM: (\{.*\}) TO: (\{.*\}) on instance/)
      if parts[0]&.length == 2
        from_msg = ''
        to_msg = ''

        from_msg = JSON.parse(parts[0][0], symbolize_names: true) if parts[0][0] != ''
        to_msg = JSON.parse(parts[0][1], symbolize_names: true) if parts[0][1] != ''

        expect(from_msg).to eq(expected[:from])
        expect(to_msg).to eq(expected[:to])
      end
    end
  end
end

module Bosh::Director::DeploymentPlan
  describe InstancePlan do
    subject(:instance_plan) do
      InstancePlan.new(
        existing_instance: existing_instance,
        desired_instance: desired_instance,
        instance: instance,
        network_plans: network_plans,
        use_dns_addresses: use_dns_addresses,
        use_short_dns_addresses: use_short_dns_addresses,
        logger: per_spec_logger,
        tags: tags,
        variables_interpolator: variables_interpolator,
        link_provider_intents: link_provider_intents,
      )
    end

    let(:variables_interpolator) { Bosh::Director::ConfigServer::VariablesInterpolator.new }
    let(:instance_group) do
      ig = InstanceGroup.parse(deployment_plan, instance_group_spec, Bosh::Director::Config.event_log, per_spec_logger)
      allow(ig).to receive(:jobs).and_return(desired_deployment_plan_jobs)
      ig
    end

    let(:desired_deployment_plan_jobs) { [] }
    let(:link_provider_intents) { [] }

    let!(:variable_set_model) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }
    let(:instance_model) do
      instance_model = FactoryBot.create(:models_instance,
        uuid: 'fake-uuid-1',
        bootstrap: true,
        deployment: deployment_model,
        spec: spec,
        variable_set: variable_set_model,
        job: 'instance-group-name',
      )
      FactoryBot.create(:models_vm, instance: instance_model, active: true, agent_id: 'active-vm-agent-id')
      instance_model
    end

    let(:spec) do
      {
        'vm_type' =>
        {
          'name' => 'original_vm_type_name',
          'cloud_properties' => { 'old' => 'value' },
        },
        'env' => { 'bosh' => { 'password' => 'foobar' } },
        'networks' => network_settings,
        'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1', 'os' => operating_system },
      }
    end

    let(:operating_system) { 'ubuntu' }
    let(:use_dns_addresses) { false }
    let(:use_short_dns_addresses) { false }
    let(:tags) do
      { 'key1' => 'value1' }
    end

    let(:desired_instance) do
      DesiredInstance.new(instance_group, deployment_plan, availability_zone)
    end
    let(:current_state) do
      { 'current' => 'state', 'job' => instance_group_spec, 'job_state' => job_state }
    end
    let(:availability_zone) { AvailabilityZone.new('foo-az', 'a' => 'b') }
    let(:instance) do
      Instance.create_from_instance_group(
        instance_group,
        1,
        instance_state,
        deployment_plan.model,
        current_state,
        availability_zone,
        per_spec_logger,
        variables_interpolator,
      )
    end
    let(:instance_state) { 'started' }
    let(:network) { ManualNetwork.parse(network_spec, [availability_zone], per_spec_logger) }
    let(:reservation) do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
      reservation.resolve_ip('192.168.1.3/32')
      reservation
    end
    let(:subnet) { DynamicNetworkSubnet.new('10.0.0.1', {}, ['foo-az'], '32') }
    let(:network_plans) do
      [
        NetworkPlanner::Plan.new(reservation: reservation, existing: true),
      ]
    end
    let(:job_state) { 'running' }
    let(:existing_instance) { instance_model }

    let(:instance_group_spec) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(env: { 'bosh' => { 'password' => 'foobar' } })
    end

    let(:network_spec) { SharedSupport::DeploymentManifestHelper.simple_cloud_config['networks'].first }
    let(:cloud_config_manifest) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }
    let(:deployment_manifest) { SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups }
    let(:deployment_model) do
      cloud_config = FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config_manifest))
      deployment = FactoryBot.create(:models_deployment,
        name: deployment_manifest['name'],
        manifest: YAML.dump(deployment_manifest),
      )
      deployment.cloud_configs = [cloud_config]
      deployment
    end
    let(:deployment_plan) do
      planner_factory = PlannerFactory.create(per_spec_logger)
      plan = planner_factory.create_from_model(deployment_model)
      Assembler.create(plan, variables_interpolator).bind_models
      plan
    end
    let(:network_settings) do
      { 'a' => { 'type' => 'dynamic', 'cloud_properties' => {}, 'dns' => ['10.0.0.1'], 'default' => %w[dns gateway] } }
    end

    before do
      fake_app
      fake_locks

      release_model = FactoryBot.create(:models_release, name: deployment_manifest['releases'].first['name'])
      version = FactoryBot.create(:models_release_version, version: deployment_manifest['releases'].first['version'])
      release_model.add_version(version)

      deployment_manifest['instance_groups'].first['jobs'].each do |job|
        template_model = FactoryBot.create(:models_template, name: job['name'])
        version.add_template(template_model)
      end

      FactoryBot.create(:models_stemcell,
        name: deployment_manifest['stemcells'].first['name'],
        version: deployment_manifest['stemcells'].first['version'],
        operating_system: operating_system,
      )

      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'

      instance.bind_existing_instance_model(instance_model)
      instance_group.add_instance_plans([instance_plan])
    end

    describe '#initialize' do
      context 'with defaults' do
        it 'correctly sets instance variables' do
          expect(instance_plan.recreate_deployment).to eq(false)
          expect(instance_plan.skip_drain).to eq(false)
        end
      end

      context 'with given values' do
        it 'correctly sets instance variables' do
          expect(instance_plan.desired_instance).to eq(desired_instance)
          expect(instance_plan.existing_instance).to eq(existing_instance)
          expect(instance_plan.instance).to eq(instance)
          expect(instance_plan.network_plans).to eq(network_plans)
          expect(instance_plan.tags).to eq('key1' => 'value1')
        end
      end
    end

    describe 'networks_changed?' do
      context 'when the instance plan has desired network plans' do
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }
        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation),
          ]
        end
        let(:network_settings) do
          {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
          }
        end

        it 'should return true' do
          expect(instance_plan.networks_changed?).to be_truthy
        end

        it 'should log the changes' do
          allow(per_spec_logger).to receive(:debug)
          expect(per_spec_logger).to receive(:debug).with(
            "networks_changed? desired reservations: [#{reservation}]",
          )

          instance_plan.networks_changed?
        end

        context 'when dns_record_name exists in network_settings' do
          let(:network_plans) do
            [
              NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
              NetworkPlanner::Plan.new(reservation: reservation, existing: true),
            ]
          end
          let(:network_settings) do
            {
              'existing-network' => {
                'type' => 'dynamic',
                'cloud_properties' => {},
                'dns_record_name' => '0.job-1.my-network.deployment.bosh',
                'dns' => '10.0.0.1',
              },
              'a' => {
                'type' => 'manual',
                'ip' => '192.168.1.3',
                'netmask' => '255.255.255.0',
                'cloud_properties' => {},
                'default' => %w[dns gateway],
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'gateway' => '192.168.1.1',
              },
            }
          end

          it 'should ignore dns_record_name when comparing old and new network_settings' do
            allow(per_spec_logger).to receive(:debug)
            expect(per_spec_logger).to_not receive(:debug).with(
              /networks_changed\? network settings changed FROM:/,
            )

            expect(instance_plan.networks_changed?).to be(false)
          end
        end

        context 'when there are obsolete plans' do
          let(:network_plans) do
            [
              NetworkPlanner::Plan.new(reservation: existing_reservation, obsolete: true),
            ]
          end
          let(:existing_reservation) do
            reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, existing_network)
            reservation.resolve_ip('10.0.0.5')
            reservation
          end

          it 'logs' do
            allow(per_spec_logger).to receive(:debug)
            expect(per_spec_logger).to receive(:debug).with(
              'networks_changed? obsolete reservations: ' \
              "[{type=dynamic, ip=10.0.0.5/32, network=existing-network, instance=#{instance_model}}]",
            )
            instance_plan.networks_changed?
          end
        end

        context 'when there are desired plans' do
          let(:network_plans) do
            [
              NetworkPlanner::Plan.new(reservation: desired_reservation),
            ]
          end
          let(:desired_reservation) do
            reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, existing_network)
            reservation.resolve_ip('10.0.0.5')
            reservation
          end

          it 'logs' do
            allow(per_spec_logger).to receive(:debug)
            expect(per_spec_logger).to receive(:debug).with(
              'networks_changed? desired reservations: ' \
              "[{type=dynamic, ip=10.0.0.5/32, network=existing-network, instance=#{instance_model}}]",
            )
            instance_plan.networks_changed?
          end
        end

        context 'when instance is being deployed for the first time' do
          let(:existing_instance) { nil }

          it 'should return true' do
            expect(instance_plan.networks_changed?).to be_truthy
          end
        end
      end
    end

    describe 'network_settings_changed?' do
      context 'when the instance plan has desired network plans' do
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }
        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation),
          ]
        end
        let(:network_settings) do
          {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
          }
        end

        it 'should return true' do
          expect(instance_plan.network_settings_changed?).to be_truthy
        end

        it 'should log the changes' do
          new_network_settings = {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'a' => {
              'type' => 'manual',
              'ip' => '192.168.1.3',
              'prefix' => '32',
              'netmask' => '255.255.255.0',
              'cloud_properties' => {},
              'default' => %w[dns gateway],
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'gateway' => '192.168.1.1',
            },
          }

          allow(per_spec_logger).to receive(:debug)
          expect(per_spec_logger).to receive(:debug).with(
            'network_settings_changed? network settings changed ' \
            "FROM: #{network_settings} TO: #{new_network_settings} on instance #{instance_plan.existing_instance}",
          )

          instance_plan.network_settings_changed?
        end

        context 'when network spec is changed during second deployment' do
          let(:network_settings) do
            {
              'existing-network' => {
                'type' => 'dynamic',
                'cloud_properties' => {},
                'dns' => '10.0.0.1',
              },
            }
          end
          let(:subnet) { DynamicNetworkSubnet.new('8.8.8.8', subnet_cloud_properties, ['foo-az'], '32') }
          let(:network_plans) { [NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true)] }
          let(:subnet_cloud_properties) do
            {}
          end

          context 'when dns is changed' do
            it 'should return true' do
              expect(instance_plan.network_settings_changed?).to be_truthy
            end
          end

          context 'when variables exist in the spec' do
            let(:current_networks_hash) do
              { 'a' => { 'b' => '((a_var))' } }
            end

            let(:interpolated_current_networks_hash) do
              { 'a' => { 'b' => 'smurf' } }
            end

            let(:desired_networks_hash) do
              { 'a' => { 'b' => '((a_var))' } }
            end

            let(:interpolated_desired_networks_hash) do
              { 'a' => { 'b' => 'gargamel' } }
            end

            let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

            let(:mock_network_settings) { instance_double(Bosh::Director::DeploymentPlan::NetworkSettings) }
            let(:mock_instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
            let(:mock_desired_instance) { instance_double(Bosh::Director::DeploymentPlan::DesiredInstance) }
            let(:mock_existing_instance) { instance_double(Bosh::Director::Models::Instance) }
            let(:simple_instance_plan) do
              InstancePlan.new(
                existing_instance: mock_existing_instance,
                desired_instance: mock_desired_instance,
                instance: mock_instance,
                variables_interpolator: variables_interpolator,
              )
            end

            let(:previous_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
            let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

            before do
              allow(mock_instance).to receive_message_chain(:model, :deployment, :name)
              allow(mock_instance).to receive(:instance_group_name)
              allow(mock_instance).to receive(:current_networks)
              allow(mock_instance).to receive(:availability_zone)
              allow(mock_instance).to receive(:index)
              allow(mock_instance).to receive(:uuid)
              allow(mock_instance).to receive(:previous_variable_set).and_return(previous_variable_set)
              allow(mock_instance).to receive(:desired_variable_set).and_return(desired_variable_set)

              allow(mock_desired_instance).to receive_message_chain(:instance_group, :default_network)

              allow(mock_existing_instance).to receive(:spec_p).and_return(current_networks_hash)

              allow(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).and_return(mock_network_settings)
              allow(mock_network_settings).to receive(:to_hash).and_return(desired_networks_hash)
            end

            it 'compares the interpolated cloud_properties' do
              expect(variables_interpolator).to receive(:interpolated_versioned_variables_changed?).with(current_networks_hash,
                                                                                                         desired_networks_hash,
                                                                                                         previous_variable_set,
                                                                                                         desired_variable_set)
                                                                                                   .and_return(true)

              expect(simple_instance_plan.network_settings_changed?).to be_truthy
            end

            it 'does not log the interpolated cloud property changes' do
              allow(variables_interpolator).to receive(:interpolated_versioned_variables_changed?).with(current_networks_hash,
                                                                                                        desired_networks_hash,
                                                                                                        previous_variable_set,
                                                                                                        desired_variable_set)
                                                                                                  .and_return(true)

              expect(per_spec_logger).to receive(:debug).with(
                'network_settings_changed? network settings changed ' \
                "FROM: #{current_networks_hash} TO: #{desired_networks_hash} on instance #{mock_existing_instance}",
              )
              expect(simple_instance_plan.network_settings_changed?).to be_truthy
            end
          end
        end
      end
    end

    describe '#needs_shutting_down?' do
      context 'when instance_plan is obsolete' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: nil,
            instance: nil,
            network_plans: network_plans,
            variables_interpolator: variables_interpolator,
          )
        end
        it 'shuts down the instance' do
          expect(instance_plan.needs_shutting_down?).to be_truthy
        end
      end

      context 'when deployment is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }
        it 'shuts down the instance' do
          expect(instance_plan.needs_shutting_down?).to be_truthy
        end
      end

      context 'when the vm type name has changed' do
        let(:subnet) { DynamicNetworkSubnet.new(['10.0.0.1'], {}, ['foo-az'], '32') }
        let(:existing_network) { DynamicNetwork.new('a', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) { [NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true)] }

        before do
          instance_plan.existing_instance.update(spec: spec.merge(
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
          ))
        end

        it 'returns false' do
          # because cloud_properties is the only part that matters
          expect(instance_plan.needs_shutting_down?).to be(false)
        end
      end

      context 'when the stemcell version has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '2' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with('stemcell_changed? changed FROM: ' \
            'version: 2 ' \
            'TO: ' \
            'version: 1' \
            ' on instance ' + instance_plan.existing_instance.to_s)
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the network has changed' do
        # everything else should be the same
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation),
          ]
        end
        let(:network_settings) do
          {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
          }
        end

        it 'should return true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end
      end

      context 'when the network settings have changed' do
        # everything else should be the same
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }

        it 'should return true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end
      end

      context 'when the network settings have NOT changed' do
        # everything else should be the same
        let(:network) { DynamicNetwork.parse(network_spec, [availability_zone], per_spec_logger) }
        let(:network_spec) do
          {
            'name' => 'a',
            'type' => 'dynamic',
            'subnets' => [
              {
                'range' => '10.0.0.0/24',
                'gateway' => '10.0.0.1',
                'az' => 'foo-az',
                'dns' => ['10.0.0.1'],
                'cloud_properties' => {},
              },
            ],
          }
        end
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }

        it 'should return false' do
          expect(instance_plan.needs_shutting_down?).to be(false)
        end
      end

      context 'when the stemcell name has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell-old', 'version' => '1' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with('stemcell_changed? changed FROM: ' \
            'ubuntu-stemcell-old ' \
            'TO: ' \
            'ubuntu-stemcell' \
            ' on instance ' + instance_plan.existing_instance.to_s)
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the env has changed' do
        let(:instance_group_spec) do
          SharedSupport::DeploymentManifestHelper.simple_instance_group(env: { 'key' => 'changed-value' })
        end

        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1' },
            'env' => { 'key' => 'previous-value' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'log the change reason' do
          expect(per_spec_logger).to receive(:debug).with(
            'env_changed? changed FROM: {"key":"previous-value"} TO: {"key":"changed-value"}' \
              ' on instance ' + instance_plan.existing_instance.to_s,
          )
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the instance is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }

        it 'shuts down the instance' do
          expect(instance_plan.needs_shutting_down?).to be_truthy
        end
      end
    end

    describe '#vm_matches_plan?' do
      let(:instance_group_spec) do
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'foo-instance-group',
          env: { 'env' => 'env-val' },
          vm_type: 'a',
        )
      end

      let(:cloud_config_manifest) do
        cc = SharedSupport::DeploymentManifestHelper.simple_cloud_config
        cc['vm_types'][0] = { 'name' => 'a', 'cloud_properties' => uninterpolated_cloud_properties_hash }
        cc
      end

      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

      let(:uninterpolated_cloud_properties_hash) do
        { 'cloud' => '((interpolated_prop))' }
      end

      let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

      let(:previous_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

      let(:desired_cloud_properties_hash) do
        { 'cloud' => 'prop' }
      end

      let(:previous_cloud_properties_hash) do
        { 'cloud' => 'prop' }
      end

      let(:simple_instance_plan) do
        InstancePlan.new(
          existing_instance: mock_existing_instance,
          desired_instance: mock_desired_instance,
          instance: mock_instance,
          variables_interpolator: variables_interpolator,
        )
      end

      let(:mock_desired_instance) do
        instance_double(
          Bosh::Director::DeploymentPlan::DesiredInstance,
          instance_group: instance_group,
          availability_zone: availability_zone,
        )
      end

      let(:mock_existing_instance) do
        instance_double(
          Bosh::Director::Models::Instance,
        )
      end

      let(:mock_instance) do
        instance_double(
          Bosh::Director::DeploymentPlan::Instance,
          previous_variable_set: previous_variable_set,
          desired_variable_set: desired_variable_set,
          stemcell: instance_double(Bosh::Director::Models::Stemcell, name: 'ubuntu-stemcell', version: '1'),
          cloud_properties: uninterpolated_cloud_properties_hash,
        )
      end

      before do
        allow(instance_group.vm_type).to receive(:cloud_properties).and_return(uninterpolated_cloud_properties_hash)
        allow(variables_interpolator).to receive(:interpolate_with_versioning).with(
          uninterpolated_cloud_properties_hash,
          desired_variable_set,
        ).and_return(desired_cloud_properties_hash)
        allow(variables_interpolator).to receive(:interpolate_with_versioning).with(
          uninterpolated_cloud_properties_hash,
          previous_variable_set,
        ).and_return(previous_cloud_properties_hash)
      end

      it 'should match if all properties are the same' do
        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'ubuntu-stemcell',
              stemcell_version: '1',
              env_json: { 'env' => 'env-val' }.to_json,
              cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
              active: true,
            ),
          ),
        ).to eq(true)
      end

      it 'should not match if cloud_properties are nil' do
        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'ubuntu-stemcell',
              stemcell_version: '1',
              env_json: { 'env' => 'env-val' }.to_json,
              cloud_properties_json: nil,
              active: true,
            ),
          ),
        ).to eq(false)
      end

      it 'should not match if stemcell differs' do
        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'other-stemcell',
              stemcell_version: '1',
              env_json: { 'env' => 'env-val' }.to_json,
              cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
              active: true,
            ),
          ),
        ).to eq(false)

        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'ubuntu-stemcell',
              stemcell_version: '5',
              env_json: { 'env' => 'env-val' }.to_json,
              cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
              active: true,
            ),
          ),
        ).to eq(false)
      end

      it 'should not match if env properties differ' do
        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'ubuntu-stemcell',
              stemcell_version: '1',
              env_json: { 'other-env' => 'other-env-val' }.to_json,
              cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
              active: true,
            ),
          ),
        ).to eq(false)

        expect(
          simple_instance_plan.vm_matches_plan?(
            FactoryBot.create(:models_vm,
              instance: existing_instance,
              stemcell_name: 'ubuntu-stemcell',
              stemcell_version: '1',
              env_json: {}.to_json,
              cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
              active: true,
            ),
          ),
        ).to eq(false)
      end

      context 'when cloud properties differ' do
        let(:desired_cloud_properties_hash) do
          { 'cloud' => 'new-prop' }
        end

        it 'should not match' do
          expect(
            simple_instance_plan.vm_matches_plan?(
              FactoryBot.create(:models_vm,
                instance: existing_instance,
                stemcell_name: 'ubuntu-stemcell',
                stemcell_version: '1',
                env_json: { 'env' => 'env-val' }.to_json,
                cloud_properties_json: { 'cloud' => '((interpolated_prop))' }.to_json,
                active: true,
              ),
            ),
          ).to eq(false)
        end
      end
    end

    describe '#needs_duplicate_vm?' do
      context 'when instance_plan is obsolete' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: nil,
            instance: nil,
            network_plans: network_plans,
            variables_interpolator: variables_interpolator,
          )
        end
        it 'shuts down the instance' do
          expect(instance_plan.needs_duplicate_vm?).to be_truthy
        end
      end

      context 'when deployment is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }
        it 'shuts down the instance' do
          expect(instance_plan.needs_duplicate_vm?).to be_truthy
        end
      end

      context 'when the vm type name has changed' do
        let(:existing_network) { DynamicNetwork.new('a', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) { [NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true)] }

        before do
          instance_plan.existing_instance.update(spec: spec.merge(
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
          ))
        end

        it 'returns false' do
          # because cloud_properties is the only part that matters
          expect(instance_plan.needs_duplicate_vm?).to be(false)
        end
      end

      context 'when the stemcell version has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '2' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_duplicate_vm?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with('stemcell_changed? changed FROM: ' \
            'version: 2 ' \
            'TO: ' \
            'version: 1' \
            ' on instance ' + instance_plan.existing_instance.to_s)
          instance_plan.needs_duplicate_vm?
        end
      end

      context 'when the network has changed' do
        # everything else should be the same
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation),
          ]
        end
        let(:network_settings) do
          {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
          }
        end

        it 'should return true' do
          expect(instance_plan.needs_duplicate_vm?).to be(true)
        end
      end

      context 'when the network settings have changed' do
        # # everything else should be the same
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }

        it 'should still return false' do
          expect(instance_plan.needs_duplicate_vm?).to be(false)
        end
      end

      context 'when the stemcell name has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell-old', 'version' => '1' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_duplicate_vm?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with('stemcell_changed? changed FROM: ' \
            'ubuntu-stemcell-old ' \
            'TO: ' \
            'ubuntu-stemcell' \
            ' on instance ' + instance_plan.existing_instance.to_s)
          instance_plan.needs_duplicate_vm?
        end
      end

      context 'when the env has changed' do
        let(:instance_group_spec) do
          SharedSupport::DeploymentManifestHelper.simple_instance_group(env: { 'key' => 'changed-value' })
        end

        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1' },
            'env' => { 'key' => 'previous-value' },
          })
        end

        it 'returns true' do
          expect(instance_plan.needs_duplicate_vm?).to be(true)
        end

        it 'log the change reason' do
          expect(per_spec_logger).to receive(:debug).with(
            'env_changed? changed FROM: {"key":"previous-value"} TO: {"key":"changed-value"}' \
              ' on instance ' + instance_plan.existing_instance.to_s,
          )
          instance_plan.needs_duplicate_vm?
        end
      end

      context 'when the instance is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }

        it 'shuts down the instance' do
          expect(instance_plan.needs_duplicate_vm?).to be_truthy
        end
      end
    end

    describe 'recreate_for_non_network_reasons?' do
      context 'when deployment is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }
        it 'shuts down the instance' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be_truthy
        end
      end

      context 'when the vm type name has changed' do
        let(:existing_network) { DynamicNetwork.new('a', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) { [NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true)] }

        before do
          instance_plan.existing_instance.update(spec: spec.merge(
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
          ))
        end

        it 'returns false' do
          # because cloud_properties is the only part that matters
          expect(instance_plan.recreate_for_non_network_reasons?).to be(false)
        end
      end

      context 'when the stemcell version has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '2' },
          })
        end

        it 'returns true' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with(
            'stemcell_changed? changed FROM: ' \
            'version: 2 ' \
            'TO: ' \
            'version: 1' \
            " on instance #{instance_plan.existing_instance}",
          )
          instance_plan.recreate_for_non_network_reasons?
        end
      end

      context "when it's a multi-CPI deployment (CPIs are defined)" do
        let(:spec) do
          {
            'vm_type' =>
              {
                'name' => 'original_vm_type_name',
                'cloud_properties' => { 'old' => 'value' },
              },
            'env' => { 'bosh' => { 'password' => 'foobar' } },
            'networks' => network_settings,
            'stemcell' => { 'name' => 'deployed-stemcell', 'os' => 'ubuntu', 'version' => '1' },
          }
        end
        let(:availability_zone) { AvailabilityZone.new('foo-az', { 'old' => 'value' }, 'foo-cpi') }
        before do
          FactoryBot.create(:models_stemcell,
            name: 'deployed-stemcell',
            operating_system: 'ubuntu', # can't use deployment_manifest['stemcells'].first['os']; it's nil
            version: deployment_manifest['stemcells'].first['version'],
            cpi: 'foo-cpi',
          )
        end
        context "when the stemcell hasn't changed" do
          it "returns false because we don't need to recreate" do
            expect(instance_plan.recreate_for_non_network_reasons?).to be(false)
          end
        end
        context "when the stemcell has changed" do
          before do
            instance_plan.existing_instance.update(spec: spec.merge(
              'stemcell' => { 'os' => 'ubuntu', 'version' => '2' },
            ))
          end
          it "returns true because we need to recreate" do
            expect(instance_plan.recreate_for_non_network_reasons?).to be(true)
          end
        end
      end

      context 'when the network has changed' do
        # everything else should be the same
        let(:availability_zone) { AvailabilityZone.new('foo-az', 'old' => 'value') }
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], '32', per_spec_logger) }
        let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation),
          ]
        end
        let(:network_settings) do
          {
            'existing-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' => {
              'type' => 'dynamic',
              'cloud_properties' => {},
              'dns' => '10.0.0.1',
            },
          }
        end

        it 'should return false' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be(false)
        end
      end

      context 'when the stemcell name has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell-old', 'version' => '1' },
          })
        end

        it 'returns true' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be(true)
        end

        it 'logs the change reason' do
          expect(per_spec_logger).to receive(:debug).with(
            'stemcell_changed? changed FROM: ' \
            'ubuntu-stemcell-old ' \
            'TO: ' \
            'ubuntu-stemcell' \
            " on instance #{instance_plan.existing_instance}",
          )
          instance_plan.recreate_for_non_network_reasons?
        end
      end

      context 'when the env has changed' do
        let(:instance_group_spec) do
          SharedSupport::DeploymentManifestHelper.simple_instance_group(env: { 'key' => 'changed-value' })
        end

        before do
          instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1' },
            'env' => { 'key' => 'previous-value' },
          })
        end

        it 'returns true' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be(true)
        end

        it 'log the change reason' do
          expect(per_spec_logger).to receive(:debug).with(
            'env_changed? changed FROM: {"key":"previous-value"} TO: {"key":"changed-value"}' \
            " on instance #{instance_plan.existing_instance}",
          )
          instance_plan.recreate_for_non_network_reasons?
        end
      end

      context 'when the instance is being recreated' do
        let(:deployment) { instance_double(Planner, recreate: true) }

        it 'shuts down the instance' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be_truthy
        end
      end

      context 'when the existing instance does not have a stemcell' do
        before do
          instance_plan.existing_instance.update(spec: spec.merge(
            'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
            'stemcell' => nil,
          ))
        end

        it 'returns false for stemcell changed' do
          expect(instance_plan.recreate_for_non_network_reasons?).to be_falsey
        end
      end
    end

    describe 'stemcell_model_for_cpi' do
      before do
        FactoryBot.create(:models_stemcell,
          name: 'a-different-name-to-sidestep-uniqueness-constraints',
          version: deployment_manifest['stemcells'].first['version'],
          operating_system: operating_system,
        )
      end

      let(:cpi) { 'foo-cpi' }
      context "when there's no availability zone" do
        let(:availability_zone) { nil }
        it "returns the instance's stemcell model, which is the pre-multi-CPI behavior" do
          expect(instance_plan.stemcell_model_for_cpi(instance)).to eq(instance.stemcell.models.first)
        end
      end
      context "when there's an availability zone but no CPI" do
        it "returns the instance's stemcell model, which is the pre-multi-CPI behavior" do
          expect(instance_plan.stemcell_model_for_cpi(instance)).to eq(instance.stemcell.models.first)
        end
      end
      context "when there's a CPI but no matching stemcell models" do
        let(:availability_zone) { AvailabilityZone.new('foo-az', { 'a' => 'b' }, 'foo-cpi') }
        it "returns the instance's stemcell model, which is the pre-multi-CPI behavior" do
          expect(instance_plan.stemcell_model_for_cpi(instance)).to eq(instance.stemcell.models.first)
        end
      end
      context "when there's a CPI and there are matching models" do
        let(:availability_zone) { AvailabilityZone.new('foo-az', { 'a' => 'b' }, 'foo-cpi') }
        before do
          # A bad model, same as the good model except wrong cpi
          FactoryBot.create(:models_stemcell,
            name: deployment_manifest['stemcells'].first['name'],
            version: deployment_manifest['stemcells'].first['version'],
            operating_system: operating_system,
            cpi: 'wrong-cpi',
          )
        end
        # which fixes a bug where multi-CPI would erroneously conclude a stemcell change
        it "returns the stemcell model for the appropriate CPI" do
          good_model = FactoryBot.create(:models_stemcell,
            name: deployment_manifest['stemcells'].first['name'],
            version: deployment_manifest['stemcells'].first['version'],
            operating_system: operating_system,
            cpi: 'foo-cpi',
          )
          expect(instance_plan.stemcell_model_for_cpi(instance)).to eq(good_model)
        end
      end
    end

    describe '#persist_current_spec' do
      let(:subnet) { DynamicNetworkSubnet.new('10.0.0.1', {}, ['foo-az'], '32') }
      let(:existing_network) { DynamicNetwork.new('a', [subnet], '32', per_spec_logger) }
      let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }

      let(:network_plans) do
        [
          NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
          NetworkPlanner::Plan.new(reservation: reservation),
        ]
      end

      before do
        instance_plan.existing_instance.update(spec: {
          'vm_type' => { 'name' => 'old', 'cloud_properties' => { 'a' => 'b' } },
        })
      end

      it 'should write the current spec to the database' do
        instance_plan.persist_current_spec
        vm_type = instance_plan.existing_instance.reload.spec_p('vm_type')
        expect(vm_type).to eq('name' => 'a', 'cloud_properties' => {})
      end
    end

    describe '#recreation_requested?' do
      describe 'when nothing changes' do
        it 'should return false' do
          expect(instance_plan.recreation_requested?).to eq(false)
        end
      end

      describe 'when deployment is being recreated' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: desired_instance,
            instance: instance,
            network_plans: network_plans,
            recreate_deployment: true,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return changed' do
          expect(instance_plan.recreation_requested?).to be_truthy
        end

        it 'should log the change reason' do
          expect(per_spec_logger).to receive(:debug).with('recreation_requested? job deployment is configured with "recreate" state')
          instance_plan.recreation_requested?
        end
      end

      context 'when instance is being recreated' do
        let(:instance_state) { 'recreate' }

        it 'should return true when desired instance is in "recreate" state' do
          expect(instance_plan.recreation_requested?).to be_truthy
        end
      end

      context 'when instance is not being recreated' do
        let(:instance_state) { 'stopped' }

        it 'should return false when desired instance is in any another state' do
          expect(instance_plan.recreation_requested?).to be_falsey
        end
      end

      context 'when instance has unresponsive agent' do
        let(:job_state) { 'unresponsive' }

        it 'should return true' do
          expect(instance_plan.recreation_requested?).to be_truthy
        end
      end
    end

    describe '#recreate_persistent_disks_requested?' do
      describe 'when persistent disks in deployment are being recreated' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: desired_instance,
            instance: instance,
            network_plans: network_plans,
            recreate_persistent_disks: true,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return changed' do
          expect(instance_plan.recreate_persistent_disks_requested?).to be_truthy
        end

        it 'should log the change reason' do
          allow(per_spec_logger).to receive(:debug) do |log_line|
            expect(log_line).to eq(
              'recreate_persistent_disks_requested? job deployment is configured with "recreate_persistent_disks" state',
            )
          end

          instance_plan.recreate_persistent_disks_requested?
        end
      end
    end

    describe '#unresponsive_agent?' do
      context 'when instance has unresponsive agent' do
        let(:job_state) { 'unresponsive' }

        it 'should return true' do
          expect(instance_plan.unresponsive_agent?).to be_truthy
        end
      end

      context 'when instance is ok' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: desired_instance,
            instance: instance,
            network_plans: network_plans,
            recreate_deployment: true,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return false' do
          expect(instance_plan.unresponsive_agent?).to be_falsey
        end
      end

      context 'when instance is nil' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: desired_instance,
            instance: nil,
            network_plans: network_plans,
            recreate_deployment: true,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return false' do
          expect(instance_plan.unresponsive_agent?).to be_falsey
        end
      end
    end

    describe '#persistent_disk_changed?' do
      let(:cloud_config_manifest) do
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
        cloud_config['disk_types'] = [{
          'name' => 'disk_a',
          'disk_size' => 24,
          'cloud_properties' => {
            'new' => 'properties',
          },
        }]
        cloud_config
      end

      context 'when recreate_persistent_disks_requested' do
        let(:instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: desired_instance,
            instance: instance,
            network_plans: network_plans,
            recreate_persistent_disks: true,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return true' do
          expect(instance_plan.persistent_disk_changed?).to be(true)
        end
      end

      context 'when there is a change' do
        let(:instance_group_spec) do
          SharedSupport::DeploymentManifestHelper.simple_instance_group(persistent_disk_type: 'disk_a')
        end

        before do
          persistent_disk = FactoryBot.create(:models_persistent_disk, size: 42, cloud_properties: { 'new' => 'properties' })
          instance_plan.instance.model.add_persistent_disk(persistent_disk)
        end

        it 'should return true' do
          expect(instance_plan.persistent_disk_changed?).to be(true)
        end

        it 'should log' do
          allow(per_spec_logger).to receive(:debug)

          expect(per_spec_logger).to log_persistent_disk_change(from: {
            name: '',
            size: 42,
            cloud_properties: {
              new: 'properties',
            },
          }, to: {
            name: '',
            size: 24,
            cloud_properties: {
              new: 'properties',
            },
          })

          instance_plan.persistent_disk_changed?
        end

        context 'variables interpolation' do
          let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

          before do
            instance.desired_variable_set = desired_variable_set
          end

          it 'should create PersistentDiskCollection with the correct variable sets' do
            expect(Bosh::Director::DeploymentPlan::PersistentDiskCollection).to receive(:changed_disk_pairs).with(
              anything,
              instance.model.variable_set,
              anything,
              desired_variable_set,
            ).and_return([])

            instance_plan.persistent_disk_changed?
          end
        end
      end

      context 'when instance is obsolete' do
        let(:obsolete_instance_plan) do
          InstancePlan.new(
            existing_instance: existing_instance,
            desired_instance: nil,
            instance: nil,
            variables_interpolator: variables_interpolator,
          )
        end

        it 'should return true if instance had a persistent disk' do
          persistent_disk = FactoryBot.create(:models_persistent_disk, active: true, size: 2)
          obsolete_instance_plan.existing_instance.add_persistent_disk(persistent_disk)

          expect(obsolete_instance_plan.persistent_disk_changed?).to be_truthy
        end

        it 'should return false if instance had no persistent disk' do
          expect(obsolete_instance_plan.existing_instance.active_persistent_disks.any?).to eq(false)

          expect(obsolete_instance_plan.persistent_disk_changed?).to be_falsey
        end
      end
    end

    describe '#network_settings_hash' do
      let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }

      it 'generates network settings from the job and desired reservations' do
        expect(instance_plan.network_settings_hash).to eq(
          'a' => {
            'type' => 'manual',
            'ip' => '192.168.1.3',
            'prefix' => '32',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'default' => %w[dns gateway],
            'gateway' => '192.168.1.1',
          },
        )
      end
    end

    describe '#network_addresses' do
      let(:network_settings) { instance_double(Bosh::Director::DeploymentPlan::NetworkSettings) }
      let(:link_def) { instance_double(Bosh::Director::DeploymentPlan::Link) }

      it 'passes dns entry preferences to network settings' do
        allow(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).and_return(network_settings)

        expect(network_settings).to receive(:network_addresses).with(true)
        instance_plan.network_addresses(true)
      end
    end

    describe '#network_address' do
      let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }
      let(:network_settings) { instance_double(Bosh::Director::DeploymentPlan::NetworkSettings) }
      let(:use_dns_addresses) { true }

      context 'when use_short_dns_addresses is true' do
        let(:use_short_dns_addresses) { true }

        it 'forwards that option to the settings' do
          expect(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).with(
            anything,
            anything,
            anything,
            anything,
            anything,
            anything,
            anything,
            anything,
            anything,
            true,
            anything,
          )

          instance_plan.network_settings
        end
      end

      it 'calls it with correct value' do
        allow(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).and_return(network_settings)

        expect(network_settings).to receive(:network_address).with(use_dns_addresses)
        instance_plan.network_address
      end
    end

    describe '#link_network_addresses' do
      let(:network_settings) { instance_double(Bosh::Director::DeploymentPlan::NetworkSettings) }
      let(:link_def) { instance_double(Bosh::Director::DeploymentPlan::Link) }

      it 'passes link and dns entry preferences to network settings' do
        allow(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).and_return(network_settings)

        expect(network_settings).to receive(:link_network_addresses).with(link_def, true)
        instance_plan.link_network_addresses(link_def, true)
      end
    end

    describe '#link_network_address' do
      let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }
      let(:network_settings) { instance_double(Bosh::Director::DeploymentPlan::NetworkSettings) }
      let(:link_def) { instance_double(Bosh::Director::DeploymentPlan::Link) }

      before do
        allow(Bosh::Director::DeploymentPlan::NetworkSettings).to receive(:new).and_return(network_settings)
      end

      let(:use_dns_addresses) { true }

      it 'calls it with correct value' do
        expect(network_settings).to receive(:link_network_address).with(link_def, use_dns_addresses)
        instance_plan.link_network_address(link_def)
      end
    end

    describe '#root_domain' do
      it 'fetches root domain' do
        expect(instance_plan.root_domain).to eq('bosh')
      end
    end

    describe '#job_changed?' do
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

      context 'when an instance exists (with the same job name & instance index)' do
        let(:current_state) do
          { 'job' => instance_group.spec }
        end

        let(:current_spec) { instance_group.spec.merge('template' => 'something-random', 'random-key' => 'bogus') }

        context 'that fully matches the job spec' do
          before { allow(instance).to receive(:current_job_spec).and_return(current_spec) }

          it 'returns false' do
            expect(instance_plan.job_changed?).to eq(false)
          end
        end

        context 'when there is a different order for templates (jobs)' do
          let(:job1_template) { FactoryBot.create(:models_template, name: 'job1') }
          let(:job2_template) { FactoryBot.create(:models_template, name: 'job2') }

          let(:deployment_manifest) do
            SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(
              jobs: [
                { 'name' => 'job1', 'release' => 'bosh-release' },
                { 'name' => 'job2', 'release' => 'bosh-release' },
              ],
            )
          end

          let(:instance_group_spec) do
            SharedSupport::DeploymentManifestHelper.simple_instance_group(
              jobs: [
                { 'name' => 'job1', 'release' => 'bosh-release' },
                { 'name' => 'job2', 'release' => 'bosh-release' },
              ],
            )
          end

          let(:desired_deployment_plan_jobs) do
            [
              instance_double(
                Bosh::Director::DeploymentPlan::Job,
                model: job1_template,
              ),
              instance_double(
                Bosh::Director::DeploymentPlan::Job,
                model: job2_template,
              ),
            ]
          end

          before do
            another_spec = instance_group.spec
            job1 = another_spec['templates'].first
            job2 = another_spec['templates'][1]
            another_spec['templates'] = [job2, job1]
            allow(instance).to receive(:current_job_spec).and_return(another_spec)
          end

          it 'does not detect change' do
            expect(instance_plan.job_changed?).to be_falsey
          end
        end

        context 'that does not match the job spec' do
          before do
            allow(instance_group).to receive(:jobs).and_return([job])
            allow(instance).to receive(:current_job_spec).and_return({})
          end

          let(:job) do
            instance_double('Bosh::Director::DeploymentPlan::Job',
                            name: state['job']['name'],
                            version: state['job']['version'],
                            sha1: state['job']['sha1'],
                            blobstore_id: state['job']['blobstore_id'],
                            properties: {},
                            logs: nil)
          end
          let(:state) do
            {
              'job' => {
                'name' => 'hbase_slave',
                'template' => 'hbase_slave',
                'version' => '0+dev.9',
                'sha1' => 'a8ab636b7c340f98891178096a44c09487194f03',
                'blobstore_id' => 'e2e4e58e-a40e-43ec-bac5-fc50457d5563',
              },
            }
          end

          let(:current_state) do
            { 'job' => instance_group.spec.merge('version' => 'old-version') }
          end

          it 'returns true' do
            expect(instance_plan.job_changed?).to eq(true)
          end

          it 'logs the change' do
            expect(per_spec_logger).to receive(:debug).with(/job_changed\? changed FROM: .* TO: .*/)
            instance_plan.job_changed?
          end
        end
      end
    end

    describe '#packages_changed?' do
      describe 'when packages have changed' do
        let(:instance_model) do
          instance_model = FactoryBot.create(:models_instance,
            bootstrap: true,
            deployment: deployment_model,
            uuid: 'uuid-1',
            variable_set: variable_set_model,
            spec: { 'vm_type' => {
              'name' => 'original_vm_type_name',
              'cloud_properties' => { 'old' => 'value' },
            },
                    'packages' => { 'changed' => 'value' },
                    'networks' => network_settings,
                    'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1' } },
          )
          instance_model
        end

        it 'should return true' do
          expect(instance_plan.packages_changed?).to eq(true)
        end

        it 'should log changes' do
          expect(per_spec_logger).to receive(:debug).with('packages_changed? changed FROM: {"changed":"value"} ' \
                                                 'TO: {} on instance foobar/uuid-1 (1)')
          instance_plan.packages_changed?
        end
      end

      describe 'when packages have not changed' do
        before do
          allow(instance).to receive(:current_packages).and_return({ 'old' => {'blobstore_id' => 'id'} })
          allow(instance_group).to receive(:package_spec).and_return({ 'old' => {'blobstore_id' => 'id'} })
        end

        it 'should return false' do
          expect(instance_plan.packages_changed?).to eq(false)
        end

        context 'and signed urls are enabled' do
          before do
            allow(instance_group).to receive(:package_spec).and_return({ 'old' => {'blobstore_id' => 'id', 'signed_url' => "url" }})
          end

          it 'should sanitize the spec and return false' do
            expect(instance_plan.packages_changed?).to eq(false)
          end
        end
      end
    end

    describe '#configuration_changed?' do
      describe 'when the configuration has changed' do
        let(:spec) do
          { 'configuration_hash' => { 'old' => 'config' } }
        end

        it 'should return true' do
          instance.configuration_hash = { 'changed' => 'config' }
          expect(instance_plan.configuration_changed?).to eq(true)
        end

        it 'should log the configuration changed reason' do
          instance.configuration_hash = { 'changed' => 'config' }

          expect(per_spec_logger).to receive(:debug).with('configuration_changed? changed FROM: {"old":"config"} ' \
                                                 "TO: {\"changed\":\"config\"} on instance foobar/#{instance.model.uuid} (1)")
          instance_plan.configuration_changed?
        end
      end

      describe 'when the configuration has not changed' do
        it 'should return false' do
          expect(instance_plan.configuration_changed?).to eq(false)
        end
      end
    end

    describe '#changes' do
      before do
        instance_model.active_vm.update(
          blobstore_config_sha1: Bosh::Director::Config.blobstore_config_fingerprint,
          nats_config_sha1: Bosh::Director::Config.nats_config_fingerprint,
        )
      end

      it 'does not include nats_config or blobstore_config by default' do
        expect(instance_plan.changes).to_not include(:nats_config)
        expect(instance_plan.changes).to_not include(:blobstore_config)
      end

      context 'when the spec_json is nil' do
        before do
          instance_plan.existing_instance.update(spec_json: nil)
        end

        it 'should report changes' do
          expect(instance_plan.changes).to_not be_empty
        end
      end

      context 'when the spec_json is empty hash' do
        before do
          instance_plan.existing_instance.update(spec_json: '{}')
        end

        it 'should report changes' do
          expect(instance_plan.changes).to_not be_empty
        end
      end

      context 'when theres a change to blobstore config' do
        before do
          instance_model.active_vm.update(blobstore_config_sha1: 'new-blobstore-config')
        end

        it 'includes blobstore_config' do
          expect(instance_plan.changes).to include(:blobstore_config)
        end
      end

      context 'when theres a change to nats config' do
        before do
          instance_model.active_vm.update(nats_config_sha1: 'new-nats-config')
        end

        it 'includes nats_config' do
          expect(instance_plan.changes).to include(:nats_config)
        end
      end
    end

    describe '#should_be_ignored' do
      context 'when the instance model has ignore flag as false, default' do
        it 'should return true' do
          expect(instance_plan.should_be_ignored?).to eq(false)
        end
      end

      context 'when the instance model has ignore flag as true' do
        before do
          instance_plan.existing_instance.update(ignore: true)
        end

        it 'should return true' do
          expect(instance_plan.should_be_ignored?).to eq(true)
        end
      end
    end

    context 'when there have been changes on the instance' do
      describe '#dns_changed?' do
        let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }

        before do
          new_spec = spec
          new_spec['networks']['a'] = spec['networks']['a'].merge('ip' => '192.168.1.3')
          existing_instance.spec = new_spec
        end

        describe 'when the index dns record for the instance is not found' do
          let(:changed_instance) { Bosh::Director::Models::Instance.all.last }

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(per_spec_logger).to log_dns_change(from: [], to: [{
              ip: '192.168.1.3',
              instance_id: instance_model.id,
              az: nil,
              network: 'a',
              deployment: 'simple',
              instance_group: 'instance-group-name',
              agent_id: 'active-vm-agent-id',
              domain: 'bosh',
              links: [],
            }])
            instance_plan.dns_changed?
          end
        end

        describe 'when the local dns record has changed' do
          before do
            FactoryBot.create(:models_local_dns_record, instance_id: instance_model.id, ip: 'dummy-ip')
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            allow(per_spec_logger).to receive(:debug)
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(per_spec_logger).to log_dns_change(
              from: [{
                ip: 'dummy-ip',
                az: nil,
                instance_group: nil,
                network: nil,
                deployment: nil,
                instance_id: instance_model.id,
                agent_id: nil,
                domain: nil,
                links: [],
              }],
              to: [{
                ip: '192.168.1.3',
                instance_id: instance_model.id,
                az: nil,
                network: 'a',
                deployment: 'simple',
                instance_group: 'instance-group-name',
                agent_id: 'active-vm-agent-id',
                domain: 'bosh',
                links: [],
              }],
            )
            instance_plan.dns_changed?
          end
        end
      end
    end

    describe '#instance_group_properties' do
      context 'when job templates are present' do
        let(:desired_deployment_plan_jobs) do
          [
            instance_double(
              Bosh::Director::DeploymentPlan::Job,
              model: desired_template,
            ),
          ]
        end

        let(:link_provider_intents) do
          [
            instance_double(
              Bosh::Director::Models::Links::LinkProviderIntent,
              link_provider: provider1,
              group_name: 'desired-link-2-desired-link-type-2',
            ),
            instance_double(
              Bosh::Director::Models::Links::LinkProviderIntent,
              link_provider: provider1,
              group_name: 'desired-link-1-desired-link-type-1',
            ),
          ]
        end

        let(:desired_template) do
          instance_double(
            Bosh::Director::Models::Template,
            provides: [],
          )
        end

        let(:provider1) { double(:provider1, instance_group: 'instance-group-name') }

        it 'enumerates instance group properties and link properties' do
          properties = subject.instance_group_properties
          expect(properties).to eq(
            instance_id: instance_model.id,
            az: nil,
            deployment: 'simple',
            agent_id: 'active-vm-agent-id',
            instance_group: 'instance-group-name',
            links: [
              { name: 'desired-link-1-desired-link-type-1' },
              { name: 'desired-link-2-desired-link-type-2' },
            ],
          )
        end

        it 'sets the agent ID to nil if there is no active VM' do
          allow(instance_model).to receive(:active_vm).and_return nil
          agent_id = subject.instance_group_properties[:agent_id]
          expect(agent_id).to be_nil
        end
      end
    end

    describe '#remove_network_plans_for_ips' do
      let(:plan1) do
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
        reservation.resolve_ip('192.168.1.25/32')

        NetworkPlanner::Plan.new(reservation: reservation, existing: false, obsolete: true)
      end

      let(:plan2) do
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
        reservation.resolve_ip('192.168.1.26')

        NetworkPlanner::Plan.new(reservation: reservation, existing: false, obsolete: true)
      end

      let(:plan3) do
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
        reservation.resolve_ip('192.168.1.4')

        NetworkPlanner::Plan.new(reservation: reservation, existing: true)
      end

      let(:plan4) do
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
        reservation.resolve_ip('10.0.0.1')

        NetworkPlanner::Plan.new(reservation: reservation, existing: false, obsolete: true)
      end

      let(:network_plans) { [plan1, plan2, plan3, plan4] }

      let(:ip1) { IPAddr.new('192.168.1.25/32') }
      let(:ip2) { IPAddr.new('192.168.1.26/32') }

      let(:ip_address1) { FactoryBot.create(:models_ip_address, address_str: ip1.to_s) }
      let(:ip_address2) { FactoryBot.create(:models_ip_address, address_str: ip2.to_s) }

      describe 'when there are ips specified' do
        it 'releases obsolete network plans of the specified ips' do
          instance_plan.remove_obsolete_network_plans_for_ips([ip_address1.address_str, ip_address2.address_str])
          expect(instance_plan.network_plans).to contain_exactly(plan3, plan4)
        end
      end
    end
  end
end
