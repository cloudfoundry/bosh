require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlan do
    let(:job) { Job.parse(deployment_plan, job_spec, BD::Config.event_log, logger) }
    let(:instance_model) { BD::Models::Instance.make(bootstrap: false, deployment: deployment_model, uuid: 'uuid-1') }
    let(:desired_instance) { DesiredInstance.new(job, current_state, deployment_plan, availability_zone) }
    let(:current_state) { {'current' => 'state', 'job' => job_spec } }
    let(:availability_zone) { AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:instance) { Instance.new(job, 1, 'started', deployment_plan, current_state, availability_zone, true, logger) }
    let(:network_resolver) { GlobalNetworkResolver.new(deployment_plan) }
    let(:network) { ManualNetwork.parse(network_spec, [availability_zone], network_resolver, logger) }
    let(:reservation) {
      reservation = BD::DesiredNetworkReservation.new_dynamic(instance, network)
      reservation.resolve_ip('192.168.1.3')
      reservation
    }
    let(:network_plans) { [NetworkPlanner::Plan.new(reservation: reservation)] }
    let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: network_plans, logger: logger) }
    let(:existing_instance) { instance_model }

    let(:job_spec) do
      job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
      job['vm_type'] = 'fake-vm-type'
      job
    end
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
      planner_factory = PlannerFactory.create(BD::Config.event_log, logger)
      plan = planner_factory.create_from_model(deployment_model)
      plan.bind_models
      plan
    end

    let(:network_settings) { { 'obsolete' => 'network'} }
    before do
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
      instance_model.vm.apply_spec=({'vm_type' => 'name', 'networks' => network_settings, 'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}  })
      instance.bind_existing_instance_model(instance_model)
      job.add_instance_plans([instance_plan])
    end

    describe 'networks_changed?' do
      context 'when there are instance plan has network plans' do
        let(:subnet) { DynamicNetworkSubnet.new('10.0.0.1', {}, ['foo-az']) }
        let(:existing_network) { DynamicNetwork.new('existing-network', [subnet], logger) }
        let(:existing_reservation) { reservation = BD::DesiredNetworkReservation.new_dynamic(instance, existing_network) }
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
              'dns_record_name' => '1.foobar.existing-network.simple.bosh'
            },
            'obsolete-network' =>{
              'type' => 'dynamic',
              'cloud_properties' =>{},
              'dns' => '10.0.0.1',
              'dns_record_name' => '1.foobar.obsolete-network.simple.bosh'
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
              'dns_record_name' => '1.foobar.existing-network.simple.bosh'
            },
            'a' =>{
              'ip' => '192.168.1.3',
              'netmask' => '255.255.255.0',
              'cloud_properties' =>{},
              'dns' =>['192.168.1.1', '192.168.1.2'],
              'gateway' => '192.168.1.1',
              'dns_record_name' => '1.foobar.a.simple.bosh'
            }
          }

          expect(logger).to receive(:debug).with(
              "networks_changed? changed FROM: #{network_settings} TO: #{new_network_settings} on instance #{instance_plan.existing_instance}"
            )

          instance_plan.networks_changed?
        end

        context 'when instance is being deployed for the first time' do
          let(:existing_instance) { nil }

          it 'should return true' do
            expect(instance_plan.networks_changed?).to be_truthy
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

      context 'when the vm type has changed' do
        before do
          instance_plan.existing_instance.vm.update(apply_spec: {'vm_type' => { 'name' => 'old', 'cloud_properties' => {'old' => 'value'}}})
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'logs the change reason' do
          expect(logger).to receive(:debug).with('vm_type_changed? changed FROM: ' +
                '{"name"=>"old", "cloud_properties"=>{"old"=>"value"}} ' +
                'TO: ' +
                '{"name"=>"a", "cloud_properties"=>{}}' +
                ' on instance ' + "#{instance_plan.existing_instance}"
            )
          instance_plan.needs_shutting_down?
        end
      end

      context 'when the stemcell type has changed' do
        before do
          expect(instance_plan).to receive(:vm_type_changed?).and_return(false)
          instance_plan.existing_instance.vm.update(apply_spec: {
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
          expect(instance_plan).to receive(:vm_type_changed?).and_return(false)
          instance_plan.existing_instance.vm.update(env: {'key' => 'previous-value'})
        end

        it 'returns true' do
          expect(instance_plan.needs_shutting_down?).to be(true)
        end

        it 'log the change reason' do
          expect(logger).to receive(:debug).with('env_changed? changed FROM: {"key"=>"previous-value"} TO: {"key"=>"changed-value"}' +
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
        let(:desired_instance) { DesiredInstance.new(job, 'recreate') }

        it 'should return true when desired instance is in "recreate" state' do
          expect(instance_plan.needs_recreate?).to be_truthy
        end
      end

      context 'when instance is not being recreated' do
        let(:desired_instance) { DesiredInstance.new(job, 'stopped') }

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
        job['vm_type'] = 'fake-vm-type'
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
      context 'when instance plan is obsolete' do
        it 'gets the network settings from the existing instance spec (because its the last known instance state)' do
         obsolete_instance_plan = InstancePlan.new(existing_instance: existing_instance, instance: nil, desired_instance: nil)

          expect(obsolete_instance_plan.network_settings_hash).to eq({'obsolete' => 'network'})
        end
      end

      context 'when instance plan is not obsolete' do
        it 'generates network settings from the job and desired reservations' do
          expect(instance_plan.network_settings_hash).to eq({
              'a' => {
                'ip' => '192.168.1.3',
                'netmask' => '255.255.255.0',
                'cloud_properties' =>{},
                'dns' =>['192.168.1.1', '192.168.1.2'],
                'gateway' => '192.168.1.1',
                'dns_record_name' => '1.foobar.a.simple.bosh'}
              }
            )
        end

        context 'when instance has no desired reservations' do
          it 'gets the network settings from the existing instance spec (because its the last known instance state)' do
            instance_plan.network_plans = []

            expect(instance_plan.network_settings_hash).to eq({'obsolete' => 'network'})
          end
        end
      end
    end

    context 'when there have been changes on the instance' do
      describe '#bootstrap_changed?' do
        context 'when bootstrap node changes' do
          before do
            desired_instance.mark_as_bootstrap
          end

          it 'adds :bootstrap to the set of changes' do
            expect(instance_plan.changes).to include(:bootstrap)
          end
        end

        context 'when bootstrap node remains the same' do
          it 'changes do not include bootstrap' do
            expect(instance_plan.changes).not_to include(:bootstrap)
          end
        end

        context 'when instance plan does not have existing instance' do
          let(:existing_instance) { nil }

          it 'changes include bootstrap' do
            expect(instance_plan.changes).to include(:bootstrap)
          end
        end
      end

      describe '#dns_changed?' do
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
