require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlan do
    subject(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: network_plans, logger: logger, tags: tags) }

    let(:instance_group) { InstanceGroup.parse(deployment_plan, instance_group_spec, BD::Config.event_log, logger) }

    let(:variable_set_model) { BD::Models::VariableSet.make(deployment: deployment_model) }
    let(:instance_model) do
      instance_model = BD::Models::Instance.make(
        uuid: 'fake-uuid-1',
        bootstrap: true,
        deployment: deployment_model,
        spec: spec,
        variable_set: variable_set_model
      )
      instance_model
    end
    let(:spec) do
      { 'vm_type' =>
          { 'name' => 'original_vm_type_name',
            'cloud_properties' => {'old' => 'value'}
          },
        'networks' => network_settings,
        'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}
      }
    end

    let(:tags) do
      {'key1' => 'value1'}
    end

    let(:desired_instance) { DesiredInstance.new(instance_group, deployment_plan, availability_zone) }
    let(:current_state) { {'current' => 'state', 'job' => instance_group_spec, 'job_state' => job_state } }
    let(:availability_zone) { AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:instance) { Instance.create_from_job(instance_group, 1, instance_state, deployment_plan, current_state, availability_zone, logger) }
    let(:instance_state) { 'started' }
    let(:network_resolver) { GlobalNetworkResolver.new(deployment_plan, [], logger) }
    let(:network) { ManualNetwork.parse(network_spec, [availability_zone], network_resolver, logger) }
    let(:reservation) {
      reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
      reservation.resolve_ip('192.168.1.3')
      reservation
    }
    let(:network_plans) { [] }
    let(:job_state) { 'running' }
    let(:existing_instance) { instance_model }

    let(:instance_group_spec) { Bosh::Spec::Deployments.simple_manifest['jobs'].first }
    let(:network_spec) { Bosh::Spec::Deployments.simple_cloud_config['networks'].first }
    let(:cloud_config_manifest) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:deployment_manifest) { Bosh::Spec::Deployments.simple_manifest }
    let(:deployment_model) do
      cloud_config = BD::Models::CloudConfig.make(manifest: cloud_config_manifest)
      BD::Models::Deployment.make(
        name: deployment_manifest['name'],
        manifest: YAML.dump(deployment_manifest),
        cloud_config: cloud_config,
      )
    end

    let(:deployment_plan) do
      planner_factory = PlannerFactory.create(logger)
      plan = planner_factory.create_from_model(deployment_model)
      plan.bind_models
      plan
    end

    let(:network_settings) { { 'obsolete' => 'network'} }
    before do
      BD::Models::VariableSet.make(deployment: deployment_model)
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
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
          expect(instance_plan.tags).to eq({'key1' => 'value1'})
        end
      end
    end

    describe 'networks_changed?' do
      context 'when the instance plan has desired network plans' do
        let(:subnet) { DynamicNetworkSubnet.new('10.0.0.1', {}, ['foo-az']) }
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], logger) }
        let(:existing_reservation) { reservation = BD::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }
        let(:network_plans) {[
         NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
         NetworkPlanner::Plan.new(reservation: reservation)
        ]}
        let(:network_settings) do
          {
            'existing-network' =>{
              'type' => 'dynamic',
              'cloud_properties' =>{},
              'dns' => '10.0.0.1',
            },
            'obsolete-network' =>{
              'type' => 'dynamic',
              'cloud_properties' =>{},
              'dns' => '10.0.0.1',
            }
          }
        end

        it 'should return true' do
          expect(instance_plan.networks_changed?).to be_truthy
        end

        it 'should log the changes' do
          new_network_settings = {
            'existing-network' =>{
              'type' => 'dynamic',
              'cloud_properties' =>{},
              'dns' => '10.0.0.1',
            },
            'a' =>{
              'ip' => '192.168.1.3',
              'netmask' => '255.255.255.0',
              'cloud_properties' =>{},
              'default' => ['dns', 'gateway'],
              'dns' =>['192.168.1.1', '192.168.1.2'],
              'gateway' => '192.168.1.1',
            }
          }

          allow(logger).to receive(:debug)
          expect(logger).to receive(:debug).with(
              "networks_changed? network settings changed FROM: #{network_settings} TO: #{new_network_settings} on instance #{instance_plan.existing_instance}"
            )

          instance_plan.networks_changed?
        end

        context 'when dns_record_name exists in network_settings' do
          let(:network_plans) { [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: reservation, existing: true)
          ] }
          let(:network_settings) do
            {
              'existing-network' => {
                'type' => 'dynamic',
                'cloud_properties' => {},
                'dns_record_name' => '0.job-1.my-network.deployment.bosh',
                'dns' => '10.0.0.1',
              },
              'a' => {
                'ip' => '192.168.1.3',
                'netmask' => '255.255.255.0',
                'cloud_properties' => {},
                'default' => ['dns', 'gateway'],
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'gateway' => '192.168.1.1'
              }
            }
          end

          it 'should ignore dns_record_name when comparing old and new network_settings' do
            allow(logger).to receive(:debug)
            expect(logger).to_not receive(:debug).with(
              /networks_changed\? network settings changed FROM:/
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
            reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, existing_network)
            reservation.resolve_ip('10.0.0.5')
            reservation
          end

          it 'logs' do
            allow(logger).to receive(:debug)
            expect(logger).to receive(:debug).with(
                "networks_changed? obsolete reservations: [{type=dynamic, ip=10.0.0.5, network=existing-network, instance=#{instance_model}}]"
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
            reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, existing_network)
            reservation.resolve_ip('10.0.0.5')
            reservation
          end

          it 'logs' do
            allow(logger).to receive(:debug)
            expect(logger).to receive(:debug).with(
                "networks_changed? desired reservations: [{type=dynamic, ip=10.0.0.5, network=existing-network, instance=#{instance_model}}]"
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

        context 'when network spec is changed during second deployment' do
          let(:network_settings) do
            {
              'existing-network' =>{
                'type' => 'dynamic',
                'cloud_properties' =>{},
                'dns' => '10.0.0.1',
              }
            }
          end
          let(:subnet) { DynamicNetworkSubnet.new('8.8.8.8', {}, ['foo-az']) }
          let(:network_plans) { [NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true)] }

          context 'when dns is changed' do
            it 'should return true' do
              expect(instance_plan.networks_changed?).to be_truthy
            end
          end
        end
      end
    end

    describe '#needs_shutting_down?' do
      context 'when instance_plan is obsolete' do
        let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: nil, instance: nil, network_plans: network_plans) }
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
        before do
          instance_plan.existing_instance.update(spec: {
              'vm_type' => { 'name' => 'old', 'cloud_properties' => {'a' => 'b'}},
              'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1'},
              'env' => {'bosh' => { 'password' => 'foobar' }}
            })
        end

        it 'returns false' do
          # because cloud_properties is the only part that matters
          expect(instance_plan.needs_shutting_down?).to be(false)
        end
      end

      context 'when the stemcell version has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
              'vm_type' => { 'name' => 'old', 'cloud_properties' => {'a' => 'b'}},
              'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '2'},
            })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'logs the change reason' do
          expect(logger).to receive(:debug).with('stemcell_changed? changed FROM: ' +
                'version: 2 ' +
                'TO: ' +
                'version: 1' +
                ' on instance ' + "#{instance_plan.existing_instance}"
            )
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the stemcell name has changed' do
        before do
          instance_plan.existing_instance.update(spec: {
              'vm_type' => { 'name' => 'old', 'cloud_properties' => {'a' => 'b'}},
              'stemcell' => { 'name' => 'ubuntu-stemcell-old', 'version' => '1'},
            })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'logs the change reason' do
          expect(logger).to receive(:debug).with('stemcell_changed? changed FROM: ' +
                'ubuntu-stemcell-old ' +
                'TO: ' +
                'ubuntu-stemcell' +
                ' on instance ' + "#{instance_plan.existing_instance}"
            )
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the env has changed' do
        let(:cloud_config_manifest) do
          cloud_manifest = Bosh::Spec::Deployments.simple_cloud_config
          cloud_manifest['resource_pools'].first['env'] = {'key' => 'changed-value'}
          cloud_manifest
        end

        before do
          instance_plan.existing_instance.update(spec: {
                                                   'vm_type' => { 'name' => 'old', 'cloud_properties' => {'a' => 'b'}},
                                                   'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '1'},
                                                   'env' => {'key' => 'previous-value'},
                                                 })
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'log the change reason' do
          expect(logger).to receive(:debug).with(
            'env_changed? changed FROM: {"key"=>"previous-value"} TO: {"key"=>"changed-value"}' +
            ' on instance ' + "#{instance_plan.existing_instance}")
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

    describe '#persist_current_spec' do
      let(:subnet) { DynamicNetworkSubnet.new('192.168.1.1', {}, ['foo-az']) }
      let(:existing_network) { DynamicNetwork.new('a', [subnet], logger) }
      let(:existing_reservation) { reservation = BD::DesiredNetworkReservation.new_dynamic(existing_instance, existing_network) }
      let(:network_plans) {[
          NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
          NetworkPlanner::Plan.new(reservation: reservation)
      ]}

      before do
        instance_plan.existing_instance.update(spec: {
            'vm_type' => { 'name' => 'old', 'cloud_properties' => {'a' => 'b'}}
          })
      end

      it 'should write the current spec to the database' do
        instance_plan.persist_current_spec
        vm_type = instance_plan.existing_instance.reload.spec_p('vm_type')
        expect(vm_type).to eq({'name' => 'a', 'cloud_properties' =>{}})
      end
    end

    describe '#needs_recreate?' do
      describe 'when nothing changes' do
        it 'should return false' do
          expect(instance_plan.needs_recreate?).to eq(false)
        end
      end

      describe 'when deployment is being recreated' do
        let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: network_plans, recreate_deployment: true) }

        it 'should return changed' do
          expect(instance_plan.needs_recreate?).to be_truthy
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('needs_recreate? job deployment is configured with "recreate" state')
          instance_plan.needs_recreate?
        end
      end

      context 'when instance is being recreated' do
        let(:instance_state) { 'recreate' }

        it 'should return true when desired instance is in "recreate" state' do
          expect(instance_plan.needs_recreate?).to be_truthy
        end
      end

      context 'when instance is not being recreated' do
        let(:instance_state) { 'stopped' }

        it 'should return false when desired instance is in any another state' do
          expect(instance_plan.needs_recreate?).to be_falsey
        end
      end

      context 'when instance has unresponsive agent' do
        let(:job_state) { 'unresponsive' }

        it 'should return true' do
          expect(instance_plan.needs_recreate?).to be_truthy
        end
      end
    end

    describe '#needs_to_fix?' do
      context 'when instance has unresponsive agent' do
        let(:job_state) { 'unresponsive' }

        it 'should return true' do
          expect(instance_plan.needs_to_fix?).to be_truthy
        end
      end

      context 'when instance is ok' do
        let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: network_plans, recreate_deployment: true) }

        it 'should return false' do
          expect(instance_plan.needs_to_fix?).to be_falsey
        end
      end

      context 'when instance is nil' do
        let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: nil, network_plans: network_plans, recreate_deployment: true) }

        it 'should return false' do
          expect(instance_plan.needs_to_fix?).to be_falsey
        end
      end
    end

    describe '#persistent_disk_changed?' do
      let(:cloud_config_manifest) do
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config['disk_types'] = [{
          'name' => 'disk_a',
          'disk_size' => 24,
          'cloud_properties' => {
            'new' => 'properties'
          }
        }]
        cloud_config
      end

      let(:instance_group_spec) do
        instance_group_spec = Bosh::Spec::Deployments.simple_manifest['jobs'].first
        instance_group_spec['persistent_disk_pool'] = 'disk_a'
        instance_group_spec
      end

      context 'when there is a change' do
        before do
          persistent_disk = BD::Models::PersistentDisk.make(size: 42, cloud_properties: {'new' => 'properties'})
          instance_plan.instance.model.add_persistent_disk(persistent_disk)
        end

        it 'should return true' do
          expect(instance_plan.persistent_disk_changed?).to be(true)
        end

        it 'should log' do
          allow(logger).to receive(:debug)

          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: {:name=>"", :size=>42, :cloud_properties=>{"new"=>"properties"}} TO: {:name=>"", :size=>24, :cloud_properties=>{"new"=>"properties"}} on instance foobar/1 (fake-uuid-1)')

          instance_plan.persistent_disk_changed?
        end
      end

      context 'when instance is obsolete' do
        let(:obsolete_instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: nil, instance: nil) }

        it 'should return true if instance had a persistent disk' do
          persistent_disk = BD::Models::PersistentDisk.make(active: true, size: 2)
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
        expect(instance_plan.network_settings_hash).to eq({
              'a' => {
                'ip' => '192.168.1.3',
                'netmask' => '255.255.255.0',
                'cloud_properties' => {},
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'default' => ['dns', 'gateway'],
                'gateway' => '192.168.1.1',
              }
            }
          )
      end
    end

    describe '#job_changed?' do
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

      context 'when an instance exists (with the same job name & instance index)' do
        let(:current_state) { { 'job' => instance_group.spec } }

        context 'that fully matches the job spec' do
          before { allow(instance).to receive(:current_job_spec).and_return(instance_group.spec) }

          it 'returns false' do
            expect(instance_plan.job_changed?).to eq(false)
          end
        end

        context 'that does not match the job spec' do
          before do
            instance_group.jobs = [job]
            allow(instance).to receive(:current_job_spec).and_return({})
          end
          let(:job) do
            instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: state['job']['name'],
                version: state['job']['version'],
                sha1: state['job']['sha1'],
                blobstore_id: state['job']['blobstore_id'],
                properties: {},
                logs: nil,
              })
          end
          let(:state) do
            {
              'job' => {
                'name' => 'hbase_slave',
                'template' => 'hbase_slave',
                'version' => '0+dev.9',
                'sha1' => 'a8ab636b7c340f98891178096a44c09487194f03',
                'blobstore_id' => 'e2e4e58e-a40e-43ec-bac5-fc50457d5563'
              }
            }
          end

          let(:current_state) { {'job' => instance_group.spec.merge('version' => 'old-version')} }

          it 'returns true' do
            expect(instance_plan.job_changed?).to eq(true)
          end

          it 'logs the change' do
            expect(logger).to receive(:debug).with(/job_changed\? changed FROM: .* TO: .*/)
            instance_plan.job_changed?
          end
        end
      end
    end

    describe '#packages_changed?' do
      describe 'when packages have changed' do
        let(:instance_model) do
          instance_model = BD::Models::Instance.make(
            bootstrap: true,
            deployment: deployment_model,
            uuid: 'uuid-1',
            spec: { 'vm_type' => {
                      'name' => 'original_vm_type_name',
                      'cloud_properties' => {'old' => 'value'}
                  },
            'packages' => {"changed" => "value"},
            'networks' => network_settings,
            'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}}
          )
          instance_model
        end

        it 'should return true' do
          expect(instance_plan.packages_changed?).to eq(true)
        end

        it 'should log changes' do
          expect(logger).to receive(:debug).with('packages_changed? changed FROM: {"changed"=>"value"} TO: {} on instance foobar/1 (uuid-1)')
          instance_plan.packages_changed?
        end
      end

      describe 'when packages have not changed' do
        before { allow(instance).to receive(:current_packages).and_return({}) }

        it 'should return false' do
          expect(instance_plan.packages_changed?).to eq(false)
        end
      end
    end

    describe '#configuration_changed?' do
      describe 'when the configuration has changed' do
        let(:spec) do
          {'configuration_hash' => {'old' => 'config'}}
        end

        it 'should return true' do
          instance.configuration_hash = {'changed' => 'config'}
          expect(instance_plan.configuration_changed?).to eq(true)
        end

        it 'should log the configuration changed reason' do
          instance.configuration_hash = {'changed' => 'config'}

          expect(logger).to receive(:debug).with("configuration_changed? changed FROM: {\"old\"=>\"config\"} TO: {\"changed\"=>\"config\"} on instance foobar/1 (#{instance.model.uuid})")
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

        describe 'when the index dns record for the instance is not found and local_dns is not enabled' do

          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)

            instance = BD::Models::Instance.all.last
            BD::Models::Dns::Record.create(:name => "#{instance.uuid}.foobar.a.simple.fake-dns", :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name '1.foobar.a.simple.bosh' and ip '192.168.1.3' was not found in the db.")
            instance_plan.dns_changed?
          end
        end

        describe 'when the index dns record for the instance is not found and local_dns is enabled' do
          let(:network_settings) { { 'default' => {'ip' => '1234'}} }
          let(:spec) do
            { 'name' => 'fake-name',
              'deployment' => 'fake-deployment-name',
              'vm_type' =>
              { 'name' => 'original_vm_type_name',
                'cloud_properties' => {'old' => 'value'}
              },
              'networks' => network_settings,
              'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}
            }
          end
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)

            BD::Models::Dns::Record.create(:name => "#{instance.uuid}.foobar.a.simple.bosh", :type => 'A', :content => '192.168.1.3')
            BD::Models::Dns::Record.create(:name => '1.foobar.a.simple.bosh', :type => 'A', :content => '192.168.1.3')

            Bosh::Director::Models::LocalDnsRecord.make(name: "fake-uuid-1.fake-name.default.fake-deployment-name.bosh", ip: '4321', instance_id: instance_model.id)
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

        end

        describe 'when the id dns record for the instance is not found' do
          let(:uuid) { BD::Models::Instance.all.last }

          before do
            BD::Models::Dns::Record.create(:name => "#{uuid}.foobar.a.simple.bosh", :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name '1.foobar.a.simple.bosh' and ip '192.168.1.3' was not found in the db.")
            instance_plan.dns_changed?
          end
        end

        describe 'when the dns records for the instance are found' do
          before do
            BD::Models::Dns::Record.create(:name => '1.foobar.a.simple.bosh', :type => 'A', :content => '192.168.1.3')
            BD::Models::Dns::Record.create(:name => "#{instance.uuid}.foobar.a.simple.bosh", :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return false' do
            expect(instance_plan.dns_changed?).to be(false)
          end
        end
      end
    end
  end
end
