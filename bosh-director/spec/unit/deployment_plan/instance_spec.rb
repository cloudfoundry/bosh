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
    let(:network_resolver) { GlobalNetworkResolver.new(plan) }
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::Job',
        vm_type: vm_type,
        stemcell: stemcell,
        env: env,
        name: 'fake-job',
        persistent_disk_type: disk_type,
        compilation?: false,
        is_errand?: false,
        vm_extensions: vm_extensions
      )
    end
    let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
    let(:vm_extensions) {[]}
    let(:stemcell) { make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}) }
    let(:env) { Env.new({'key' => 'value'}) }
    let(:disk_type) { nil }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }

    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment, bootstrap: true, uuid: 'uuid-1') }

    let(:current_state) { {'current' => 'state'} }
    let(:desired_instance) { DesiredInstance.new(job, current_state, plan, availability_zone, 1)}

    describe '#bind_existing_instance_model' do
      let(:job) { Job.new(logger) }

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
      it 'sets the instance model and uuid' do
        expect(instance.model).to be_nil
        expect(instance.uuid).to be_nil

        instance.bind_new_instance_model
        expect(instance.model).not_to be_nil
        expect(instance.uuid).not_to be_nil
      end
    end

    context 'applying state' do
      let(:job) { Job.new(logger) }

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

      before do
        allow(BD::AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'apply_vm_state' do
        let(:state) do
          {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'id' => 'uuid-1',
            'networks' => {'fake-network' => {'fake-network-settings' => {}}},
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test-domain',
            'persistent_disk' => 0
          }
        end
        let(:instance_spec) { InstanceSpec.new(state, instance) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          expect(agent_client).to receive(:apply).with(state).ordered
          instance.apply_vm_state(instance_spec)
          expect(instance_model.spec).to eq(state)
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
          expect(instance_model.spec['networks']).to eq({'changed' => {}})
          expect(instance_model.spec['env']).to eq('fake-env')
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
          before do
            availability_zone.cloud_properties['baz'] = 'bang'
            vm_type.cloud_properties['abcd'] = 'wera'
          end

          it 'should log the change' do
            expect(logger).to receive(:debug).with('cloud_properties_changed? changed FROM: {"a"=>"b"} TO: {"a"=>"b", "baz"=>"bang", "abcd"=>"wera"}')
            instance.cloud_properties_changed?
          end
        end

        describe 'when the availability zone cloud properties change' do
          before do
            availability_zone.cloud_properties['baz'] = 'bang'
          end

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when the resource pool cloud properties change' do
          before do
            vm_type.cloud_properties['abcd'] = 'wera'
          end

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
            before do
              vm_type.cloud_properties['abcd'] = 'wera'
            end

            it 'should return true' do
              expect(instance.cloud_properties_changed?).to be(true)
            end
          end
        end
      end
    end

    describe '#cloud_properties' do
      context 'when the instance has an availability zone' do
        it 'merges the resource pool cloud properties into the availability zone cloud properties' do
          availability_zone = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
          allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one'})
          allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)

          expect(instance.cloud_properties).to eq(
              {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
        end

        context 'when the instance has vm_extensions' do
          context 'when vm_type and vm_extensions and availability zones have some overlapping cloud properties' do
            let(:vm_extension_1) {VmExtension.new({'name' => 'fake-vm-extension-1'})}
            let(:vm_extension_2) {VmExtension.new({'name' => 'fake-vm-extension-2'})}
            let(:vm_extensions) {[vm_extension_1, vm_extension_2]}

            it 'uses the vm_type cloud_properties then the availability zones then rightmost vm_extension for overlapping values' do
              availability_zone = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
              allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one', 'other-stuff' => 'who-chares'})
              allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff', 'other-stuff' => 'i-chares'})
              allow(vm_extension_1).to receive(:cloud_properties).and_return({'fooz' => 'bar', 'resources' => 'the-new-stuff', 'food' => 'drink'})
              allow(vm_extension_2).to receive(:cloud_properties).and_return({'foo' => 'baaaz', 'food' => 'eat'})

              instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)

              expect(instance.cloud_properties).to eq({'resources' => 'the-new-stuff', 'foo' => 'baaaz', 'zone' => 'the-right-one', 'food' => 'eat', 'fooz' => 'bar', 'other-stuff' => 'i-chares'})
            end
          end
        end
      end

      context 'when the instance does not have an availability zone' do
        it 'uses just the resource pool cloud properties' do
          allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.create_from_job(job, index, state, deployment, current_state, nil, logger)

          expect(instance.cloud_properties).to eq(
              {'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
        end

        context 'when the instance has vm_extensions' do
          let(:vm_extension_1) {VmExtension.new({'name' => 'fake-vm-extension-1'})}
          let(:vm_extension_2) {VmExtension.new({'name' => 'fake-vm-extension-2'})}

          context 'when the same property exists in multiple vm_extensions' do
            let(:vm_extensions) {[vm_extension_1, vm_extension_2]}

            it 'uses the right most vm_extension\'s property value for overlapping values' do
              allow(vm_extension_1).to receive(:cloud_properties).and_return({'foo' => 'bar', 'resources' => 'the-good-stuff'})
              allow(vm_extension_2).to receive(:cloud_properties).and_return({'foo' => 'baaaz'})

              instance = Instance.create_from_job(job, index, state, deployment, current_state, nil, logger)

              expect(instance.cloud_properties).to eq({'resources' => 'the-good-stuff', 'foo' => 'baaaz'})
            end
          end

          context 'when vm_type and vm_extensions have some overlapping cloud properties' do
            let(:vm_extensions) {[vm_extension_1]}

            it 'uses the vm_type cloud_properties for overlapping values' do
              allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})
              allow(vm_extension_1).to receive(:cloud_properties).and_return({'foo' => 'bar'})

              instance = Instance.create_from_job(job, index, state, deployment, current_state, nil, logger)

              expect(instance.cloud_properties).to eq({'resources' => 'the-good-stuff', 'foo' => 'bar'})
            end
          end
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
  end
end
