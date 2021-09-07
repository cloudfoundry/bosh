require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do
    include Support::StemcellHelpers

    subject(:instance) do
      Instance.create_from_instance_group(instance_group, index, state, deployment, current_state, az, logger, variables_interpolator)
    end
    let(:index) { 0 }
    let(:state) { 'started' }
    let(:variables_interpolator) { Bosh::Director::ConfigServer::VariablesInterpolator.new }
    let(:deployment_variable_set) { Bosh::Director::Models::VariableSet.make(deployment: deployment) }

    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
      allow(Bosh::Director::Config).to receive(:dns).and_return('domain_name' => 'test_domain')
      allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
      allow(blobstore).to receive(:encryption?)
    end

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:instance_group) do
      InstanceGroup.make(
        name: 'fake_job',
        vm_type: vm_type,
        vm_extensions: vm_extensions,
      )
    end
    let(:vm_type) { VmType.new('name' => 'fake-vm-type') }
    let(:vm_extensions) { [] }
    let(:az) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', 'a' => 'b') }

    let(:instance_model) do
      instance = Bosh::Director::Models::Instance.make(deployment: deployment, bootstrap: true, uuid: 'uuid-1')
      Bosh::Director::Models::Vm.make(instance: instance, active: true)
      instance
    end

    let(:current_state) do
      { 'current' => 'state' }
    end
    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }

    describe '#bind_existing_instance_model' do
      let(:instance_model) { Bosh::Director::Models::Instance.make(bootstrap: true) }

      before do
        allow(deployment).to receive(:last_successful_variable_set).and_return(deployment_variable_set)
      end

      it 'raises an error if instance already has a model' do
        instance.bind_existing_instance_model(instance_model)

        expect do
          instance.bind_existing_instance_model(instance_model)
        end.to raise_error(Bosh::Director::DirectorError, /model is already bound/)
      end

      it 'sets the instance model' do
        instance.bind_existing_instance_model(instance_model)
        expect(instance.model).to eq(instance_model)
      end

      it 'sets the previous and desired variable sets correctly' do
        variable_set_model = Bosh::Director::Models::VariableSet.make(deployment: deployment)
        instance_model.variable_set = variable_set_model
        instance.bind_existing_instance_model(instance_model)

        expect(instance.desired_variable_set).to eq(deployment_variable_set)
        expect(instance.previous_variable_set).to eq(variable_set_model)
      end

      context 'if there is no successfully deployed variable set' do
        before do
          allow(deployment).to receive(:last_successful_variable_set).and_return(nil)
          allow(deployment).to receive(:current_variable_set).and_return(deployment_variable_set)
        end

        it 'sets the desired variable set to the current variable set' do
          variable_set_model = Bosh::Director::Models::VariableSet.make(deployment: deployment)
          instance_model.variable_set = variable_set_model
          instance.bind_existing_instance_model(instance_model)

          expect(instance.desired_variable_set).to eq(deployment_variable_set)
          expect(instance.previous_variable_set).to eq(variable_set_model)
        end
      end
    end

    describe '#bind_new_instance_model' do
      before do
        allow(deployment).to receive(:current_variable_set).and_return(deployment_variable_set)
      end

      it 'sets the instance model, uuid, and instance model variable_set' do
        expect(instance.model).to be_nil
        expect(instance.uuid).to be_nil

        instance.bind_new_instance_model
        expect(instance.model).not_to be_nil
        expect(instance.model.variable_set).to eq(deployment_variable_set)
        expect(instance.uuid).not_to be_nil
      end

      it 'sets the previous and desired variable set to current deployment variable set' do
        instance.bind_new_instance_model
        expect(instance.desired_variable_set).to eq(deployment_variable_set)
        expect(instance.previous_variable_set).to eq(deployment_variable_set)
      end
    end

    context 'applying state' do
      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

      before do
        allow(BD::AgentClient).to receive(:with_agent_id)
          .with(instance_model.agent_id, instance_model.name).and_return(agent_client)
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'apply_vm_state' do
        let(:packages) { { 'pkg' => { 'version' => '0', 'blobstore_id' => 'bsid' } } }
        let(:apply_packages) { { 'pkg' => { 'version' => '0', 'blobstore_id' => 'bsid' } } }
        let(:full_spec) do
          {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'env' => {},
            'id' => 'uuid-1',
            'networks' => { 'fake-network' => { 'fake-network-settings' => {} } },
            'packages' => packages,
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
            'networks' => { 'fake-network' => { 'fake-network-settings' => {} } },
            'packages' => apply_packages,
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test-domain',
            'persistent_disk' => 0,
          }
        end
        let(:instance_spec) { InstanceSpec.new(full_spec, instance, variables_interpolator) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          expect(agent_client).to receive(:apply).with(apply_spec).ordered
          instance.apply_vm_state(instance_spec)
          expect(instance_model.spec).to eq(full_spec)
        end

        context 'when signed urls are enabled' do
          let(:apply_packages) { { 'pkg' => { 'version' => '0', 'blobstore_id' => 'bsid', 'signed_url' => 'fake-signed-url' } } }

          before do
            allow(blobstore).to receive(:can_sign_urls?).and_return(true)
            allow(blobstore).to receive(:sign).and_return('fake-signed-url')
          end

          it 'generates signed urls for packages' do
            expect(blobstore).to receive(:sign)
            expect(agent_client).to receive(:apply).with(apply_spec).ordered
            instance.apply_vm_state(instance_spec)
          end

          context 'and encryption is enabled' do
            let(:apply_packages) do
              {
                'pkg' => {
                  'version' => '0',
                  'blobstore_id' => 'bsid',
                  'signed_url' => 'fake-signed-url',
                  'blobstore_headers' => { 'header' => 'meow' },
                },
              }
            end

            before do
              allow(blobstore).to receive(:encryption?).and_return(true)
              allow(blobstore).to receive(:signed_url_encryption_headers).and_return('header' => 'meow')
            end

            it 'adds encryption headers' do
              expect(blobstore).to receive(:signed_url_encryption_headers)
              expect(agent_client).to receive(:apply).with(apply_spec).ordered
              instance.apply_vm_state(instance_spec)
            end
          end
        end
      end

      describe '#add_state_to_model' do
        it 'updates the model and merges the given values in' do
          instance.add_state_to_model('networks' => { 'changed' => {} })

          expect(instance_model.spec_p('networks')).to eq('changed' => {})
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
          expect(logger).to receive(:debug)
            .with('trusted_certs_changed? changed '\
                  'FROM: da39a3ee5e6b4b0d3255bfef95601890afd80709 '\
                  'TO: e88d62015cb4220631fec64c7db420761a50cc6b')
          instance.trusted_certs_changed?
        end
      end

      describe 'when trusted certs have not changed' do
        it 'should return false' do
          expect(instance.trusted_certs_changed?).to be(false)
        end
      end
    end

    describe '#blobstore_config_changed?' do
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when blobstore config has changed' do
        before do
          allow(Bosh::Director::Config).to receive(:blobstore_config_fingerprint).and_return('new fingerprint')
        end

        it 'should return true' do
          expect(instance.blobstore_config_changed?).to be(true)
        end

        it 'should log the change reason' do
          allow(instance_model).to receive(:blobstore_config_sha1).and_return('old fingerprint')
          expect(logger).to receive(:debug)
            .with('blobstore_config_changed? changed '\
                  'FROM: old fingerprint '\
                  'TO: new fingerprint')
          instance.blobstore_config_changed?
        end
      end

      describe 'when blobstore config has not changed' do
        before do
          allow(Bosh::Director::Config).to receive(:blobstore_config_fingerprint).and_return(instance_model.blobstore_config_sha1)
        end

        it 'should return false' do
          expect(instance.blobstore_config_changed?).to be(false)
        end
      end
    end

    describe '#nats_config_changed?' do
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when nats config has changed' do
        before do
          allow(Bosh::Director::Config).to receive(:nats_config_fingerprint).and_return('new fingerprint')
        end

        it 'should return true' do
          expect(instance.nats_config_changed?).to be(true)
        end

        it 'should log the change reason' do
          allow(instance_model).to receive(:nats_config_sha1).and_return('old fingerprint')
          expect(logger).to receive(:debug)
            .with('nats_config_changed? changed '\
                  'FROM: old fingerprint '\
                  'TO: new fingerprint')
          instance.nats_config_changed?
        end
      end

      describe 'when nats config has not changed' do
        before do
          allow(Bosh::Director::Config).to receive(:nats_config_fingerprint).and_return(instance_model.blobstore_config_sha1)
        end

        it 'should return false' do
          expect(instance.nats_config_changed?).to be(false)
        end
      end
    end

    describe '#cloud_properties_changed?' do
      let(:instance_model) do
        model = Bosh::Director::Models::Instance.make(deployment: deployment)
        model.cloud_properties_hash = { 'a' => 'b' }
        model
      end
      before do
        allow(deployment).to receive(:current_variable_set).and_return(deployment_variable_set)
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when neither the resource pool cloud properties, nor the availability zone cloud properties change' do
        it 'should return false' do
          expect(instance.cloud_properties_changed?).to eq(false)
        end
      end

      describe 'when the cloud properties change' do
        describe 'logging' do
          context 'cloud properties does NOT have variables' do
            let(:vm_type) { VmType.new('name' => '', 'cloud_properties' => { 'baz' => 'bang' }) }
            let(:vm_extensions) { [VmExtension.new('name' => '', 'cloud_properties' => { 'a' => 'b' })] }
            let(:az) { AvailabilityZone.new('az', 'abcd' => 'wera') }

            it 'should log the change' do
              expect(logger).to receive(:debug)
                .with('cloud_properties_changed? changed FROM: {"a"=>"b"} TO: {"abcd"=>"wera", "baz"=>"bang", "a"=>"b"}')
              instance.cloud_properties_changed?
            end
          end

          context 'cloud properties has variables' do
            let(:vm_type) { VmType.new('name' => '', 'cloud_properties' => { 'baz' => '((/placeholder1))' }) }
            let(:vm_extensions) { [VmExtension.new('name' => '', 'cloud_properties' => { 'a' => '((/placeholder2))' })] }
            let(:az) { AvailabilityZone.new('az', 'abcd' => '((/placeholder3))') }
            let(:merged_cloud_properties) do
              { 'abcd' => '((/placeholder3))', 'baz' => '((/placeholder1))', 'a' => '((/placeholder2))' }
            end
            let(:interpolated_merged_cloud_properties) do
              { 'abcd' => 'p1', 'baz' => 'p2', 'a' => 'p3' }
            end

            let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
            let(:previous_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

            before do
              instance.desired_variable_set = desired_variable_set

              expect(variables_interpolator).to receive(:interpolated_versioned_variables_changed?)
                .with(instance_model.cloud_properties_hash, merged_cloud_properties,
                      instance.model.variable_set, desired_variable_set)
                .and_return(true)
            end

            it 'should NOT log the interpolated values' do
              expect(logger).to receive(:debug)
                .with('cloud_properties_changed? changed '\
                      "FROM: #{instance_model.cloud_properties_hash} "\
                      "TO: #{merged_cloud_properties}")
              instance.cloud_properties_changed?
            end
          end
        end

        describe 'when the availability zone cloud properties change' do
          let(:az) { AvailabilityZone.new('az', 'naz' => 'bang') }

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when the resource pool cloud properties change' do
          let(:vm_type) { VmType.new('name' => '', 'cloud_properties' => { 'abcd' => 'wera' }) }

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when there is no availability zone' do
          let(:az) { nil }
          let(:instance_model) do
            model = Bosh::Director::Models::Instance.make(deployment: deployment)
            model.cloud_properties_hash = {}
            model
          end

          describe 'and resource pool cloud properties has not changed' do
            it 'should return false' do
              expect(instance.cloud_properties_changed?).to be(false)
            end
          end

          describe 'when there is no availability zone and resource pool cloud properties change' do
            let(:vm_type) { VmType.new('name' => '', 'cloud_properties' => { 'abcd' => 'wera' }) }

            it 'should return true' do
              expect(instance.cloud_properties_changed?).to be(true)
            end
          end
        end
      end

      describe 'variables interpolation' do
        let(:vm_type) do
          VmType.new(
            'name' => 'a',
            'cloud_properties' => { 'vm_cloud_prop' => '((/placeholder1))' },
          )
        end
        let(:vm_extensions) do
          [VmExtension.new(
            'name' => 'b',
            'cloud_properties' => { 'vm_ext_cloud_prop' => '((/placeholder2))' },
          )]
        end
        let(:az) do
          AvailabilityZone.new(
            'az',
            'az_cloud_prop' => '((/placeholder3))',
          )
        end
        let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
        let(:previous_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
        let(:merged_cloud_properties) do
          {
            'az_cloud_prop' => '((/placeholder3))',
            'vm_cloud_prop' => '((/placeholder1))',
            'vm_ext_cloud_prop' => '((/placeholder2))',
          }
        end
        let(:interpolated_merged_cloud_properties) do
          { 'vm_cloud_prop' => 'p1', 'vm_ext_cloud_prop' => 'p2', 'az_cloud_prop' => 'p3' }
        end
        let(:interpolated_existing_cloud_properties) do
          { 'vm_ext_cloud_prop' => 'p2', 'az_cloud_prop' => 'p3', 'vm_cloud_prop' => 'p1' }
        end

        before do
          instance.desired_variable_set = desired_variable_set
        end

        it 'interpolates previous and desired cloud properties with the correct variable set' do
          expect(variables_interpolator).to receive(:interpolated_versioned_variables_changed?)
            .with(instance_model.cloud_properties_hash, merged_cloud_properties,
                  instance.model.variable_set, desired_variable_set)
            .and_return(false)

          expect(instance.cloud_properties_changed?).to be_falsey
        end

        context 'when interpolated values are different' do
          it 'return true' do
            expect(variables_interpolator).to receive(:interpolated_versioned_variables_changed?)
              .with(instance_model.cloud_properties_hash, merged_cloud_properties,
                    instance.model.variable_set, desired_variable_set)
              .and_return(true)

            expect(instance.cloud_properties_changed?).to be_truthy
          end
        end
      end
    end

    describe '#update_instance_settings' do
      let(:fake_cert) { 'super trustworthy cert' }
      let(:persistent_disk_model) do
        instance_double(Bosh::Director::Models::PersistentDisk, name: 'some-disk', disk_cid: 'some-cid')
      end
      let(:disk_collection_model) do
        instance_double(
          Bosh::Director::DeploymentPlan::PersistentDiskCollection::ModelPersistentDisk,
          model: persistent_disk_model,
        )
      end
      let(:active_persistent_disks) do
        instance_double(Bosh::Director::DeploymentPlan::PersistentDiskCollection, collection: [disk_collection_model])
      end
      let(:agent_client) { instance_double(Bosh::Director::AgentClient) }
      let(:vm) { instance_model.active_vm }

      before do
        allow(instance_model).to receive(:active_persistent_disks).and_return(active_persistent_disks)
        allow(Bosh::Director::AgentClient).to receive(:with_agent_id)
          .with(vm.agent_id, instance_model.name).and_return(agent_client)
        allow(Bosh::Director::Config).to receive(:trusted_certs).and_return(fake_cert)
        allow(persistent_disk_model).to receive(:managed?).and_return(true)
        instance.bind_existing_instance_model(instance_model)
        instance_model.active_vm.update(trusted_certs_sha1: 'trusted-cert-sha')
      end

      context 'when there are non managed disks' do
        before do
          allow(persistent_disk_model).to receive(:managed?).and_return(false)
        end

        it 'tells the agent to update instance settings and updates the instance model' do
          expect(agent_client).to receive(:update_settings).with(hash_including('disk_associations' => [{ 'name' => 'some-disk', 'cid' => 'some-cid' }]))
          instance.update_instance_settings(vm)
        end
      end

      context 'when all disks are managed' do
        before do
          allow(persistent_disk_model).to receive(:managed?).and_return(true)
        end

        it 'does not send any disk associations to update' do
          expect(agent_client).to receive(:update_settings).with(hash_including('disk_associations' => []))
          instance.update_instance_settings(vm)
        end
      end

      it 'updates the agent settings and VM table with configured trusted certs' do
        expect(agent_client).to receive(:update_settings).with(hash_including('trusted_certs' => fake_cert))
        expect { instance.update_instance_settings(vm) }.to change {
          vm.reload.trusted_certs_sha1
        }.from('trusted-cert-sha').to(::Digest::SHA1.hexdigest(fake_cert))
      end
    end

    describe '#update_cloud_properties' do
      it 'saves the cloud properties' do
        az = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
        allow(az).to receive(:cloud_properties).and_return('foo' => 'az-foo', 'zone' => 'the-right-one')
        allow(vm_type).to receive(:cloud_properties).and_return('foo' => 'rp-foo', 'resources' => 'the-good-stuff')

        instance = Instance.create_from_instance_group(instance_group, index, state, deployment, current_state, az, logger, variables_interpolator)
        instance.bind_existing_instance_model(instance_model)

        instance.update_cloud_properties!

        expect(instance_model.cloud_properties_hash).to eq(
          'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo',
        )
      end
    end

    describe '#update_variable_set' do
      let(:fixed_time) { Time.now }

      it 'updates the instance model variable set to the desired_variable_set on the instance object' do
        Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time + 1)
        selected_variable_set = Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time)
        Bosh::Director::Models::VariableSet.make(deployment: deployment, created_at: fixed_time - 1)

        instance = Instance.create_from_instance_group(instance_group, index, state, deployment, current_state, az, logger, variables_interpolator)
        instance.bind_existing_instance_model(instance_model)

        instance.desired_variable_set = selected_variable_set

        instance.update_variable_set

        instance_model = Bosh::Director::Models::Instance.all.first
        expect(instance_model.variable_set).to eq(selected_variable_set)
      end
    end
  end
end
