require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlan do
    let(:job) { Job.parse(deployment_plan, job_spec, BD::Config.event_log, logger) }
    let(:instance_model) do
      instance_model = BD::Models::Instance.make(
        bootstrap: true,
        deployment: deployment_model,
        uuid: 'uuid-1',
        spec: spec
      )
      instance_model
    end
    let(:spec) do
      { 'vm_type' => {
        'name' => 'original_vm_type_name',
        'cloud_properties' => {'old' => 'value'}
      },
        'networks' => network_settings,
        'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}
      }
    end

    let(:desired_instance) { DesiredInstance.new(job, deployment_plan, availability_zone) }
    let(:current_state) { {'current' => 'state', 'job' => job_spec } }
    let(:availability_zone) { AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:instance) { Instance.create_from_job(job, 1, instance_state, deployment_plan, current_state, availability_zone, logger) }
    let(:instance_state) { 'started' }
    let(:network_resolver) { GlobalNetworkResolver.new(deployment_plan) }
    let(:network) { ManualNetwork.parse(network_spec, [availability_zone], network_resolver, logger) }
    let(:reservation) {
      reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
      reservation.resolve_ip('192.168.1.3')
      reservation
    }
    let(:network_plans) { [] }
    let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: network_plans, logger: logger) }
    let(:existing_instance) { instance_model }

    let(:job_spec) { Bosh::Spec::Deployments.simple_manifest['jobs'].first }
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
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
      instance.bind_existing_instance_model(instance_model)
      job.add_instance_plans([instance_plan])
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

      context 'when the stemcell type has changed' do
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
        expect(instance_plan.existing_instance.reload.spec['vm_type']).to eq({'name' => 'a', 'cloud_properties' =>{}})
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

      let(:job_spec) do
        job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
        job['persistent_disk_pool'] = 'disk_a'
        job
      end

      context 'when disk size changes' do
        before do
          persistent_disk = BD::Models::PersistentDisk.make(size: 42, cloud_properties: {'new' => 'properties'})
          instance_plan.instance.model.add_persistent_disk(persistent_disk)
        end

        it 'should return true' do
          expect(instance_plan.persistent_disk_changed?).to be(true)
        end

        it 'should log' do
          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: disk size: 42 TO: disk size: 24' +
                ' on instance ' + "#{instance_plan.existing_instance}")
          instance_plan.persistent_disk_changed?
        end
      end

      context 'when disk pool size is greater than 0 and disk properties changed' do
        it 'should log the disk properties change' do
          persistent_disk = BD::Models::PersistentDisk.make(size: 24, cloud_properties: {'old' => 'properties'})
          instance_plan.instance.model.add_persistent_disk(persistent_disk)

          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: {"old"=>"properties"} TO: {"new"=>"properties"}' +
                ' on instance ' + "#{instance_plan.existing_instance}")
          instance_plan.persistent_disk_changed?
        end
      end

      context 'when disk pool with size 0 is used' do
        let(:cloud_config_manifest) do
          cloud_config = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config['disk_types'] = [{
              'name' => 'disk_a',
              'disk_size' => 0,
              'cloud_properties' => {
                'new' => 'properties'
              }
            }]
          cloud_config
        end

        context 'when disk_size is still 0' do
          it 'returns false' do
            expect(instance_plan.persistent_disk_changed?).to be(false)
          end
        end
      end

      context 'when instance is obsolete' do
        let(:obsolete_instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: nil, instance: nil) }

        it 'should return true if instance had a persistent disk' do
          persistent_disk = BD::Models::PersistentDisk.make
          obsolete_instance_plan.existing_instance.add_persistent_disk(persistent_disk)

          expect(obsolete_instance_plan.persistent_disk_changed?).to be_truthy
        end

        it 'should return false if instance had no persistent disk' do
          expect(obsolete_instance_plan.existing_instance.persistent_disk).to be_nil

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
        let(:current_state) { { 'job' => job.spec } }

        context 'that fully matches the job spec' do
          before { allow(instance).to receive(:current_job_spec).and_return(job.spec) }

          it 'returns false' do
            expect(instance_plan.job_changed?).to eq(false)
          end
        end

        context 'that does not match the job spec' do
          before do
            job.templates = [template]
            allow(instance).to receive(:current_job_spec).and_return({})
          end
          let(:template) do
            instance_double('Bosh::Director::DeploymentPlan::Template', {
                name: state['job']['name'],
                version: state['job']['version'],
                sha1: state['job']['sha1'],
                blobstore_id: state['job']['blobstore_id'],
                template_scoped_properties: {},
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

          let(:current_state) { {'job' => job.spec.merge('version' => 'old-version')} }

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

          expect(logger).to receive(:debug).with('configuration_changed? changed FROM: {"old"=>"config"} TO: {"changed"=>"config"} on instance foobar/1 (uuid-1)')
          instance_plan.configuration_changed?
        end
      end

      describe 'when the configuration has not changed' do
        it 'should return false' do
          expect(instance_plan.configuration_changed?).to eq(false)
        end
      end
    end

    context 'when there have been changes on the instance' do
      describe '#dns_changed?' do
        let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }

        describe 'when the index dns record for the instance is not found' do
          before do
            BD::Models::Dns::Record.create(:name => 'uuid-1.foobar.a.simple.fake-dns', :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name '1.foobar.a.simple.bosh' and ip '192.168.1.3' was not found in the db.")
            instance_plan.dns_changed?
          end
        end

        describe 'when the id dns record for the instance is not found' do
          before do
            BD::Models::Dns::Record.create(:name => '1.foobar.a.simple.bosh', :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name 'uuid-1.foobar.a.simple.bosh' and ip '192.168.1.3' was not found in the db.")
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
