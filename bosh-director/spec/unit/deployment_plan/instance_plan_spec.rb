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
    let(:network_plan) { NetworkPlan.new(reservation: reservation) }
    let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: [network_plan]) }
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

    before do
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
      instance_model.vm.apply_spec=({'vm_type' => 'name', 'networks' => { 'obsolete' => 'network'}, 'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}  })
      instance.bind_existing_instance_model(instance_model)
      job.add_instance_plans([instance_plan])
    end

    describe '#recreate_deployment?' do
      describe 'when nothing changes' do
        it 'should return false' do
          expect(instance_plan.recreate_deployment?).to eq(false)
        end
      end

      describe "when the job's deployment is configured for recreate" do
        let(:deployment_plan) do
          planner_factory = PlannerFactory.create(BD::Config.event_log, logger)
          manifest = Psych.load(deployment_model.manifest)
          plan = planner_factory.create_from_manifest(manifest, deployment_model.cloud_config, {'recreate' => true})
          plan.bind_models
          plan
        end

        it 'should return changed' do
          expect(instance_plan.recreate_deployment?).to be_truthy
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('recreate_deployment? job deployment is configured with "recreate" state')
          instance_plan.recreate_deployment?
        end
      end
    end

    describe '#vm_type_changed?' do
      before do
        instance_plan.existing_instance.vm.update(apply_spec: {'vm_type' => { 'name' => 'fake-vm-type2', 'cloud_properties' => {'bar' => 'baz'}}})
      end

      describe 'when the vm types spec does not match the existing state' do
        it 'should return changed' do
          expect(instance_plan.vm_type_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('vm_type_changed? changed FROM: ' +
                '{"name"=>"fake-vm-type2", "cloud_properties"=>{"bar"=>"baz"}} ' +
                'TO: ' +
                '{"name"=>"a", "cloud_properties"=>{}}')
          instance_plan.vm_type_changed?
        end
      end
    end

    describe '#stemcell_changed?' do
      describe 'when there is no change in stemcell' do
        it 'should return no change' do
          expect(instance_plan.stemcell_changed?).to be(false)
        end
      end


      describe 'when the stemcell spec does not match the existing state' do
        before do
          instance_plan.existing_instance.vm.update(apply_spec: {
            'stemcell' => { 'name' => 'ubuntu-stemcell', 'version' => '2'},
          })
        end

        it 'should return changed' do
          expect(instance_plan.stemcell_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('stemcell_changed? changed FROM: ' +
                'version: 2 ' +
                'TO: ' +
                'version: 1')
          instance_plan.stemcell_changed?
        end
      end
    end

    describe '#env_changed?' do
      describe 'when nothing changes' do
        it 'should return false' do
          expect(instance_plan.env_changed?).to eq(false)
        end
      end

      describe 'when the resource pool env changes' do
        let(:cloud_config_manifest) do
          cloud_manifest = Bosh::Spec::Deployments.simple_cloud_config
          cloud_manifest['resource_pools'].first['env'] = {'key' => 'changed-value'}
          cloud_manifest
        end

        it 'detects resource pool changes when instance VM env changes' do
          instance_plan.existing_instance.vm.update(env: {'key' => 'previous-value'})

          expect(instance_plan.env_changed?).to be(true)
        end

        it 'should log the diff when the resource pool env changes' do
          instance_plan.existing_instance.vm.update(env: {'key' => 'previous-value'})

          expect(logger).to receive(:debug).with('env_changed? changed FROM: {"key"=>"previous-value"} TO: {"key"=>"changed-value"}')
          instance_plan.env_changed?
        end
      end
    end

    describe '#needs_recreate?' do
      context 'when instance is obsolete' do
        it 'should return false' do
          obsolete_instance_plan = InstancePlan.new(existing_instance: existing_instance, desired_instance: nil, instance: nil)

          expect(obsolete_instance_plan.needs_recreate?).to be_falsey
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
          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: disk size: 42 TO: disk size: 24')
          instance_plan.persistent_disk_changed?
        end
      end

      context 'when disk pool size is greater than 0 and disk properties changed' do
        it 'should log the disk properties change' do
          persistent_disk = BD::Models::PersistentDisk.make(size: 24, cloud_properties: {'old' => 'properties'})
          instance_plan.instance.model.add_persistent_disk(persistent_disk)

          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: {"old"=>"properties"} TO: {"new"=>"properties"}')
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
      context '#bootstrap_changed?' do
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
