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
        can_run_as_errand?: false
      )
    end
    let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
    let(:stemcell) { make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}) }
    let(:env) { Env.new({'key' => 'value'}) }
    let(:disk_type) { nil }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:vm) { Vm.new }

    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment, bootstrap: true, uuid: 'uuid-1') }
    let(:vm_model) { Bosh::Director::Models::Vm.make }

    let(:current_state) { {'current' => 'state'} }
    let(:desired_instance) { DesiredInstance.new(job, current_state, plan, availability_zone, 1)}

    describe '#configuration_changed?' do
      let(:job) { Job.new(logger) }

      describe 'when the configuration has changed' do
        let(:current_state) { {'configuration_hash' => {'changed' => 'value'}} }

        it 'should return true' do
          expect(instance.configuration_changed?).to eq(true)
        end

        it 'should log the configuration changed reason' do
          expect(logger).to receive(:debug).with('configuration_changed? changed FROM: {"changed"=>"value"} TO: ')
          instance.configuration_changed?
        end
      end

      describe 'when the configuration has not changed' do
        it 'should return false' do
          expect(instance.configuration_changed?).to eq(false)
        end
      end
    end

    describe '#bind_unallocated_vm' do
      let(:index) { 2 }
      let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }
      let(:old_ip) { NetAddr::CIDR.create('10.0.0.5').to_i }
      let(:vm_ip) { NetAddr::CIDR.create('10.0.0.3').to_i }
      let(:vm) { Vm.new }

      before do
        allow(job).to receive(:vm_type).and_return(vm_type)
        allow(job).to receive(:stemcell).and_return(stemcell)
      end

      it 'creates a new VM and binds it the instance' do
        instance.bind_unallocated_vm

        expect(instance.model).not_to be_nil
        expect(instance.vm).not_to be_nil
        expect(instance.vm.bound_instance).to eq(instance)
      end

      it 'creates a new uuid for each instance' do
        allow(SecureRandom).to receive(:uuid).and_return('uuid-1', 'uuid-2')
        first_instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)
        first_instance.bind_unallocated_vm
        first_uuid = first_instance.uuid
        index = 1
        second_instance = Instance.create_from_job(job, index, state, deployment, current_state, availability_zone, logger)
        second_instance.bind_unallocated_vm
        second_uuid = second_instance.uuid
        expect(first_uuid).to_not be_nil
        expect(second_uuid).to_not be_nil
        expect(first_uuid).to_not eq(second_uuid)
      end
    end

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
        expect(instance.vm).to_not be_nil
        expect(instance.vm.model).to be(instance_model.vm)
        expect(instance.vm.bound_instance).to be(instance)
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
        allow(Bosh::Director::AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client)
        instance.bind_existing_instance_model(instance_model)
        instance.bind_unallocated_vm
        instance.bind_to_vm_model(vm_model)
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
          expect(instance.current_state).to eq(state)
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

    describe '#bind_to_vm_model' do
      before do
        instance.bind_unallocated_vm
        instance.bind_to_vm_model(vm_model)
      end

      it 'updates instance model with new vm model' do
        expect(instance.model.refresh.vm).to eq(vm_model)
        expect(instance.vm.model).to eq(vm_model)
        expect(instance.vm.bound_instance).to eq(instance)
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
      end

      context 'when the instance does not have an availability zone' do
        it 'uses just the resource pool cloud properties' do
          allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.create_from_job(job, index, state, deployment, current_state, nil, logger)

          expect(instance.cloud_properties).to eq(
              {'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
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
