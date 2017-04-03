require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do
    include Support::StemcellHelpers

    subject(:instance) { Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger) }
    let(:index) { 0 }
    let(:state) { 'started' }
    let(:in_memory_ip_repo) { InMemoryIpRepo.new(logger) }
    let(:ip_provider) { IpProvider.new(in_memory_ip_repo, {}, logger) }

    before { allow(Bosh::Director::Config).to receive(:dns).and_return({'domain_name' => 'test_domain'}) }
    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
    end

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:network_resolver) { GlobalNetworkResolver.new(plan, [], logger) }
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        vm_type: vm_type,
        stemcell: stemcell,
        env: env,
        name: 'fake-job',
        persistent_disk_collection: PersistentDiskCollection.new(logger),
        compilation?: false,
        is_errand?: false,
        vm_extensions: vm_extensions
      )
    end
    let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
    let(:vm_extensions) {[]}
    let(:stemcell) { make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}) }
    let(:env) { Env.new({'key' => 'value'}) }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }

    let(:vm_model) { Bosh::Director::Models::Vm.make() }
    let(:instance_model) do
      instance = Bosh::Director::Models::Instance.make(deployment: deployment, bootstrap: true, uuid: 'uuid-1')
      instance.add_vm vm_model
      instance.active_vm = vm_model
      instance
    end

    let(:current_state) { {'current' => 'state'} }
    let(:desired_instance) { DesiredInstance.new(job, current_state, plan, availability_zone, 1)}

    describe '#bind_existing_instance_model' do
      let(:job) { InstanceGroup.new(logger) }

      let(:network) do
        instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network', reserve: nil)
      end

      let(:instance_model) { Bosh::Director::Models::Instance.make(bootstrap: true) }

      it 'raises an error if instance already has a model' do
        instance.bind_existing_instance_model(instance_model)

        expect {
          instance.bind_existing_instance_model(instance_model)
        }.to raise_error(Bosh::Director::DirectorError, /model is already bound/)
      end

      it 'sets the instance model' do
        instance.bind_existing_instance_model(instance_model)
        expect(instance.model).to eq(instance_model)
      end
    end

    describe '#bind_new_instance_model' do
      it 'sets the instance model, uuid, and instance model variable_set' do
        variable_set_model = Bosh::Director::Models::VariableSet.make(deployment: deployment)

        expect(instance.model).to be_nil
        expect(instance.uuid).to be_nil

        instance.bind_new_instance_model
        expect(instance.model).not_to be_nil
        expect(instance.model.variable_set).to eq(variable_set_model)
        expect(instance.uuid).not_to be_nil
      end
    end

    context 'applying state' do
      let(:job) { InstanceGroup.new(logger) }

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

      before do
        allow(BD::AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'apply_vm_state' do
        let(:full_spec) do
          {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'env' => {},
            'id' => 'uuid-1',
            'networks' => {'fake-network' => {'fake-network-settings' => {}}},
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test-domain',
            'persistent_disk' => 0,
            'properties' => {},
          }
        end
        let(:apply_spec) do
          {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'id' => 'uuid-1',
            'networks' => {'fake-network' => {'fake-network-settings' => {}}},
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test-domain',
            'persistent_disk' => 0,
          }
        end
        let(:instance_spec) { InstanceSpec.new(full_spec, instance) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          expect(agent_client).to receive(:apply).with(apply_spec).ordered
          instance.apply_vm_state(instance_spec)
          expect(instance_model.spec).to eq(full_spec)
        end
      end

      describe 'apply_initial_vm_state' do
        let(:apply_spec) do
          {
            'networks' => {'fake-network' => {'fake-network-settings' => {}}},
            'deployment' => 'fake-deployment',
            'job' => 'fake-job',
            'index' => 5,
            'id' => 'fake-uuid',
            'env' => 'fake-env',
            'unneeded-properties' => 'nope'
          }
        end
        let(:instance_spec) { InstanceSpec.new(apply_spec, instance) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          instance_apply_spec = instance_spec.as_apply_spec
          expect(agent_client).to receive(:apply).with({
            'networks' => instance_apply_spec['networks'],
            'deployment' => instance_apply_spec['deployment'],
            'job' => instance_apply_spec['job'],
            'index' => instance_apply_spec['index'],
            'id' => instance_apply_spec['id'],
          }).ordered

          agent_state = {'networks' => {'changed' => {}}}
          expect(agent_client).to receive(:get_state).and_return(agent_state).ordered

          instance.apply_initial_vm_state(instance_spec)
          expect(instance_model.spec_p('networks')).to eq({'changed' => {}})
          expect(instance_model.spec_p('env')).to eq('fake-env')
        end
      end
    end

    describe '#trusted_certs_changed?' do
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when trusted certs have changed' do
        let(:trusted_certs) { "Trust me. I know what I'm doing." }

        before do
          Bosh::Director::Config.trusted_certs = trusted_certs
        end

        it 'should return true' do
          expect(instance.trusted_certs_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('trusted_certs_changed? changed FROM: da39a3ee5e6b4b0d3255bfef95601890afd80709 TO: e88d62015cb4220631fec64c7db420761a50cc6b')
          instance.trusted_certs_changed?
        end
      end

      describe 'when trusted certs have not changed' do
        it 'should return false' do
          expect(instance.trusted_certs_changed?).to be(false)
        end
      end
    end

    describe '#cloud_properties_changed?' do
      let(:instance_model) {
        model = Bosh::Director::Models::Instance.make(deployment: deployment)
        model.cloud_properties_hash = {'a' => 'b'}
        model
      }
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when neither the resource pool cloud properties, nor the availability zone cloud properties change' do
        it 'should return false' do
          expect(instance.cloud_properties_changed?).to eq(false)
        end
      end

      describe 'when the cloud properties change' do

        describe 'logging' do
          let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'baz' => 'bang'}})}
          let(:vm_extensions) { [VmExtension.new({'name' => '', 'cloud_properties' => {'a' => 'b'}})]}
          let(:availability_zone) { AvailabilityZone.new('az', {'abcd' => 'wera'})}

          it 'should log the change' do
            expect(logger).to receive(:debug).with('cloud_properties_changed? changed FROM: {"a"=>"b"} TO: {"abcd"=>"wera", "baz"=>"bang", "a"=>"b"}')
            instance.cloud_properties_changed?
          end
        end

        describe 'when the availability zone cloud properties change' do
          let(:availability_zone) { AvailabilityZone.new('az', {'naz' => 'bang'})}

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when the resource pool cloud properties change' do
          let(:vm_type) { VmType.new({'name' =>'', 'cloud_properties' => {'abcd' => 'wera'}}) }

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when there is no availability zone' do
          let(:availability_zone) { nil }
          let(:instance_model) {
            model = Bosh::Director::Models::Instance.make(deployment: deployment)
            model.cloud_properties_hash = {}
            model
          }

          describe 'and resource pool cloud properties has not changed' do
            it 'should return false' do
              expect(instance.cloud_properties_changed?).to be(false)
            end
          end

          describe 'when there is no availability zone and resource pool cloud properties change' do
            let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'abcd' => 'wera'}}) }

            it 'should return true' do
              expect(instance.cloud_properties_changed?).to be(true)
            end
          end
        end
      end
    end

    describe '#update_instance_settings' do
      let(:fake_cert) { 'super trustworthy cert' }
      let(:persistent_disk_model) { instance_double(Bosh::Director::Models::PersistentDisk, name: 'some-disk', disk_cid: 'some-cid')}
      let(:disk_collection_model) { instance_double(Bosh::Director::DeploymentPlan::PersistentDiskCollection::ModelPersistentDisk, model: persistent_disk_model)}
      let(:active_persistent_disks) { instance_double(Bosh::Director::DeploymentPlan::PersistentDiskCollection, collection: [disk_collection_model]) }
      let(:agent_client) { instance_double(Bosh::Director::AgentClient) }

      before do
        allow(instance_model).to receive(:active_persistent_disks).and_return(active_persistent_disks)
        allow(Bosh::Director::AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
        allow(Bosh::Director::Config).to receive(:trusted_certs).and_return(fake_cert)
        instance.bind_existing_instance_model(instance_model)
      end

      context 'when there are non managed disks' do
        before do
          allow(persistent_disk_model).to receive(:managed?).and_return(false)
        end

        it 'tells the agent to update instance settings and updates the instance model' do
          expect(agent_client).to receive(:update_settings).with(fake_cert, [{'name' => 'some-disk', 'cid' => 'some-cid'}])
          instance.update_instance_settings
          expect(instance.model.active_vm.trusted_certs_sha1).to eq(::Digest::SHA1.hexdigest(fake_cert))
        end
      end

      context 'when all disks are managed' do
        before do
          allow(persistent_disk_model).to receive(:managed?).and_return(true)
        end

        it 'does not send any disk associations to update' do
          expect(agent_client).to receive(:update_settings).with(fake_cert, [])
          instance.update_instance_settings
          expect(instance.model.active_vm.trusted_certs_sha1).to eq(::Digest::SHA1.hexdigest(fake_cert))
        end
      end
    end

    describe '#update_cloud_properties' do
      it 'saves the cloud properties' do
        availability_zone = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
        allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one'})
        allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

        instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)
        instance.bind_existing_instance_model(instance_model)

        instance.update_cloud_properties!

        expect(instance_model.cloud_properties_hash).to eq(
            {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
          )

      end
    end

    describe '#stemcell_cid' do
      it 'asks the stemcell business object to return the cid for the given az' do
        expect(stemcell).to receive(:cid_for_az).with(instance.availability_zone_name).and_return('test-cid')
        expect(instance.stemcell_cid).to eq('test-cid')
      end
    end

    describe '#variable_set' do
      let(:fixed_time) { Time.now }
      let(:first_variable_set) { Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time - 1) }
      let(:second_variable_set) { Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time + 1) }

      before do
        instance_model.update(variable_set: first_variable_set)
        second_variable_set
      end

      context 'variable_set is not set' do
        let(:instance) { Instance.create_from_job(job, index, "recreate", deployment, current_state, availability_zone, logger) }
        it 'should return the variable set from instance model' do
          instance.bind_existing_instance_model(instance_model)
          expect(instance.variable_set).to eq(first_variable_set)
        end
      end

      context 'variable_set is set' do
        let(:instance) { Instance.create_from_job(job, index, "recreate", deployment, current_state, availability_zone, logger) }

        it 'should return the set variable_set' do
          instance.bind_existing_instance_model(instance_model)
          instance.variable_set = second_variable_set
          expect(instance.variable_set).to eq(second_variable_set)
        end
      end
    end

    describe '#update_variable_set' do
      let(:fixed_time) { Time.now }

      context 'variable_set is set' do
        it 'is updated on the model' do
          Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time + 1)
          selected_variable_set = Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time)
          Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time - 1)

          instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)
          instance.bind_existing_instance_model(instance_model)

          instance.variable_set = selected_variable_set

          instance.update_variable_set

          instance_model = Bosh::Director::Models::Instance.all.first
          expect(instance_model.variable_set).to eq(selected_variable_set)
        end
      end

      context 'variable_set is not defined' do
        it 'updates the instance model with the variable_set from the database' do
          Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time)
          oldest_variable_set = Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time - 1)
          instance_model.update(variable_set: oldest_variable_set)

          instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)
          instance.bind_existing_instance_model(instance_model)

          instance.update_variable_set

          expect(instance_model.variable_set).to eq(oldest_variable_set)
        end
      end
    end
  end
end
