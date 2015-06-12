require 'spec_helper'
require 'logger'

module Bosh::Director
  describe InstanceUpdater::VmUpdater do
    subject(:updater) { described_class.new(instance, vm_model, agent_client, job_renderer, cloud, 2, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
    let(:vm_model) { instance_double('Bosh::Director::Models::Vm') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:job_renderer) { instance_double('Bosh::Director::JobRenderer') }
    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#update' do
      def self.it_updates_vm(new_disk_cid)
        before { allow(InstanceUpdater::VmUpdater::DiskDetacher).to receive(:new).and_return(disk_detacher) }
        let(:disk_detacher) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskDetacher', detach: nil) }

        let(:vm_deleter) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter') }
        let(:vm_creator) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmCreator') }
        let(:disk_attacher) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskAttacher') }

        it 'updates vm and returns new vm model and agent client' do
          new_vm_model = instance_double('Bosh::Director::Models::Vm')
          new_agent_client = instance_double('Bosh::Director::AgentClient')

          expect(InstanceUpdater::VmUpdater::DiskDetacher).to receive(:new).
            with(instance, vm_model, agent_client, cloud, logger).
            and_return(disk_detacher)

          expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
            with(instance, vm_model, cloud, logger).
            and_return(vm_deleter)

          expect(InstanceUpdater::VmUpdater::VmCreator).to receive(:new).
            with(instance, cloud, logger).
            and_return(vm_creator)

          expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
            with(instance, new_vm_model, new_agent_client, cloud, logger).
            and_return(disk_attacher)

          expect(disk_detacher).to receive(:detach).with(no_args).ordered
          expect(vm_deleter).to receive(:delete).with(no_args).ordered
          expect(vm_creator).to receive(:create).with(new_disk_cid).ordered.and_return([new_vm_model, new_agent_client])
          expect(disk_attacher).to receive(:attach).with(no_args).ordered

          # Re-renders job templates because agent can return changed dynamic network configuration
          expect(instance).to receive(:apply_vm_state).with(no_args).ordered
          expect(job_renderer).to receive(:render_job_instance).with(instance).ordered

          expect(updater.update(new_disk_cid)).to eq([new_vm_model, new_agent_client])
        end

        context 'when disk attacher fails with Bosh::Clouds::NoDiskSpace that can be retried' do
          before { allow(disk_attacher).to receive(:attach).and_raise(error) }
          let(:error) { Bosh::Clouds::NoDiskSpace.new(true) }

          before do
            @vm_model1 = instance_double('Bosh::Director::Models::Vm')
            @vm_model2 = instance_double('Bosh::Director::Models::Vm')

            @agent_client1 = instance_double('Bosh::Director::AgentClient')
            @agent_client2 = instance_double('Bosh::Director::AgentClient')

            @vm_deleter1 = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')
            @vm_deleter2 = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')

            @vm_creator1 = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmCreator')
            @vm_creator2 = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmCreator')

            @disk_attacher2 = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskAttacher')
          end

          context 'when creating/deleting/attaching-disk succeeds in given number of retries' do
            it 'stops retrying deleting/creating/attaching-disk vm and raises CloudNotEnoughDiskSpace error' do
              expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
                with(instance, vm_model, cloud, logger).and_return(@vm_deleter1) # first delete original vm
              expect(@vm_deleter1).to receive(:delete).once.with(no_args)

              expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
                with(instance, @vm_model1, cloud, logger).and_return(@vm_deleter2)
              expect(@vm_deleter2).to receive(:delete).once.with(no_args)

              expect(InstanceUpdater::VmUpdater::VmCreator).to receive(:new).
                with(instance, cloud, logger).and_return(@vm_creator1, @vm_creator2)
              expect(@vm_creator1).to receive(:create).once.with(new_disk_cid).and_return([@vm_model1, @agent_client1])
              expect(@vm_creator2).to receive(:create).once.with(new_disk_cid).and_return([@vm_model2, @agent_client2])

              expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
                with(instance, @vm_model1, @agent_client1, cloud, logger).and_return(disk_attacher)
              expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
                with(instance, @vm_model2, @agent_client2, cloud, logger).and_return(@disk_attacher2)

              # Succeeds on the last try
              expect(@disk_attacher2).to receive(:attach).once.with(no_args)

              # Make sure we are not trying to detach disk that never was attached
              expect(InstanceUpdater::VmUpdater::DiskDetacher).to receive(:new).once.and_return(disk_detacher)
              expect(disk_detacher).to receive(:detach).once

              # Re-renders job templates because agent can return changed dynamic network configuration
              expect(instance).to receive(:apply_vm_state).with(no_args)
              expect(job_renderer).to receive(:render_job_instance).with(instance)

              expect { updater.update(new_disk_cid) }.to_not raise_error
            end
          end

          context 'when creating/deleting/attaching-disk does not succeed in given number of retries' do
            before { allow(instance).to receive(:to_s).and_return('fake-instance') }

            it 'stops retrying deleting/creating/attaching-disk vm and raises CloudNotEnoughDiskSpace error' do
              expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
                with(instance, vm_model, cloud, logger).and_return(@vm_deleter1) # first delete original vm
              expect(@vm_deleter1).to receive(:delete).once.with(no_args)

              expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
                with(instance, @vm_model1, cloud, logger).and_return(@vm_deleter2)
              expect(@vm_deleter2).to receive(:delete).once.with(no_args)

              expect(InstanceUpdater::VmUpdater::VmCreator).to receive(:new).
                with(instance, cloud, logger).and_return(@vm_creator1, @vm_creator2)
              expect(@vm_creator1).to receive(:create).once.with(new_disk_cid).and_return([@vm_model1, @agent_client1])
              expect(@vm_creator2).to receive(:create).once.with(new_disk_cid).and_return([@vm_model2, @agent_client2])

              expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
                with(instance, @vm_model1, @agent_client1, cloud, logger).and_return(disk_attacher)
              expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
                with(instance, @vm_model2, @agent_client2, cloud, logger).and_return(@disk_attacher2)

              # Last try fails
              expect(@disk_attacher2).to receive(:attach).once.with(no_args).and_raise(error)

              # Make sure we are not trying to detach disk that never was attached
              expect(InstanceUpdater::VmUpdater::DiskDetacher).to receive(:new).once.and_return(disk_detacher)
              expect(disk_detacher).to receive(:detach).once

              expect {
                updater.update(new_disk_cid)
              }.to raise_error(
                Bosh::Director::CloudNotEnoughDiskSpace,
                "Not enough disk space to update `fake-instance'",
              )
            end
          end
        end

        context 'when disk attacher fails with Bosh::Clouds::NoDiskSpace that cannot be retried' do
          before { allow(disk_attacher).to receive(:attach).and_raise(error) }
          let(:error) { Bosh::Clouds::NoDiskSpace.new(false) }

          before { allow(instance).to receive(:to_s).and_return('fake-instance') }

          before { allow(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).and_return(disk_attacher) }
          let(:disk_attacher) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskAttacher') }

          it 'does not retry deleting/creating/attaching-disk vm and raises CloudNotEnoughDiskSpace error' do
            vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')
            allow(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).and_return(vm_deleter)

            vm_creator = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmCreator')
            allow(InstanceUpdater::VmUpdater::VmCreator).to receive(:new).and_return(vm_creator)

            # only first iteration
            expect(vm_deleter).to receive(:delete).once
            expect(vm_creator).to receive(:create).once
            expect(disk_attacher).to receive(:attach).once

            expect {
              updater.update(new_disk_cid)
            }.to raise_error(
              Bosh::Director::CloudNotEnoughDiskSpace,
              "Not enough disk space to update `fake-instance'",
            )
          end
        end

        context 'when disk attacher fails with non-NoDiskSpace error' do
          before { allow(disk_attacher).to receive(:attach).and_raise(error) }
          let(:error) { Exception.new }

          before { allow(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).and_return(disk_attacher) }
          let(:disk_attacher) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskAttacher') }

          it 'does not retry deleting/creating/attaching-disk vm and raises same error' do
            vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')
            allow(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).and_return(vm_deleter)

            vm_creator = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmCreator')
            allow(InstanceUpdater::VmUpdater::VmCreator).to receive(:new).and_return(vm_creator)

            # only first iteration
            expect(vm_deleter).to receive(:delete).once
            expect(vm_creator).to receive(:create).once
            expect(disk_attacher).to receive(:attach).once

            expect { updater.update(new_disk_cid) }.to raise_error(error)
          end
        end
      end

      context 'when instance does not require resource pool change' do
        before { allow(instance).to receive(:resource_pool_changed?).with(no_args).and_return(false) }

        context 'when new disk cid is not provided' do
          it 'does not try to delete vm or detach its disk' do
            expect(InstanceUpdater::VmUpdater::DiskDetacher).to_not receive(:new)
            expect(InstanceUpdater::VmUpdater::VmDeleter).to_not receive(:new)
            updater.update(nil)
          end
        end

        context('when new disk cid is provided') { it_updates_vm('fake-disk-cid') }
      end

      context 'when instance requires resource pool change' do
        before { allow(instance).to receive(:resource_pool_changed?).with(no_args).and_return(true) }
        context('when new disk cid is not provided') { it_updates_vm(nil) }
        context('when new disk cid is provided') { it_updates_vm('fake-disk-cid') }
      end
    end

    describe '#detach' do
      it 'detaches the disk and deletes vm, updating resource pool with one empty vm' do
        disk_detacher = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskDetacher')
        expect(InstanceUpdater::VmUpdater::DiskDetacher).to receive(:new).
          with(instance, vm_model, agent_client, cloud, logger).
          and_return(disk_detacher)

        vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')
        expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
          with(instance, vm_model, cloud, logger).
          and_return(vm_deleter)

        job = instance_double('Bosh::Director::DeploymentPlan::Job')
        allow(instance).to receive(:job).with(no_args).and_return(job)

        resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        allow(job).to receive(:resource_pool).with(no_args).and_return(resource_pool)

        expect(disk_detacher).to receive(:detach).with(no_args).ordered
        expect(vm_deleter).to receive(:delete).with(no_args).ordered
        expect(resource_pool).to receive(:add_idle_vm).with(no_args).ordered

        updater.detach
      end
    end

    describe '#attach_missing_disk' do
      before { allow(instance).to receive(:model).with(no_args).and_return(instance_model) }
      let(:instance_model) { instance_double('Bosh::Director::Models::Instance') }

      context 'when no persistent disk cid exists' do
        before { allow(instance_model).to receive(:persistent_disk_cid).with(no_args).and_return(nil) }

        context 'when disk is not currently attached' do
          before { allow(instance).to receive(:disk_currently_attached?).with(no_args).and_return(false) }

          it 'does not attach disk' do
            expect(InstanceUpdater::VmUpdater::DiskAttacher).to_not receive(:new)
            updater.attach_missing_disk
          end
        end

        context 'when disk is currently attached' do
          before { allow(instance).to receive(:disk_currently_attached?).with(no_args).and_return(true) }

          it 'does not attach disk' do
            expect(InstanceUpdater::VmUpdater::DiskAttacher).to_not receive(:new)
            updater.attach_missing_disk
          end
        end
      end

      context 'when persistent disk cid exists' do
        before { allow(instance_model).to receive(:persistent_disk_cid).and_return('fake-disk-cid') }

        context 'when disk is not currently attached' do
          before { allow(instance).to receive(:disk_currently_attached?).with(no_args).and_return(false) }

          before { allow(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).and_return(disk_attacher) }
          let(:disk_attacher) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater::DiskAttacher') }

          it 'tries to attach disk' do
            expect(InstanceUpdater::VmUpdater::DiskAttacher).to receive(:new).
              with(instance, vm_model, agent_client, cloud, logger).
              and_return(disk_attacher)

            expect(disk_attacher).to receive(:attach).with(no_args)

            updater.attach_missing_disk
          end

          context 'when attaching the missing disk fails with Bosh::Clouds::NoDiskSpace' do
            before { allow(disk_attacher).to receive(:attach).and_raise(error) }
            let(:error) { Bosh::Clouds::NoDiskSpace.new(true) }

            it 'updates the vm' do
              expect(updater).to receive(:update).with('fake-disk-cid')
              updater.attach_missing_disk
            end
          end

          context 'when attaching the missing disk fails with non-NoDiskSpace' do
            before { allow(disk_attacher).to receive(:attach).and_raise(error) }
            let(:error) { Exception.new }

            it 'does not try to update the vm and raises same error' do
              expect(updater).to_not receive(:update)
              expect { updater.attach_missing_disk }.to raise_error(error)
            end
          end
        end

        context 'when disk is currently attached' do
          before { allow(instance).to receive(:disk_currently_attached?).with(no_args).and_return(true) }

          it 'does not attach disk' do
            expect(InstanceUpdater::VmUpdater::DiskAttacher).to_not receive(:new)
            updater.attach_missing_disk
          end
        end
      end
    end
  end

  describe InstanceUpdater::VmUpdater::VmCreator do
    subject!(:vm_creator) { described_class.new(instance, cloud, logger) }
    let(:deployment_vm) { instance_double('Bosh::Director::DeploymentPlan::Vm')}
    let(:instance) {
      instance_double('Bosh::Director::DeploymentPlan::Instance',
        model: instance_model,
        bind_to_vm_model: nil,
        vm: deployment_vm) }
    let(:instance_model) { Models::Instance.make(vm: nil) }
    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#create' do
      before { allow(instance).to receive(:job).with(no_args).and_return(job) }
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }

      before { allow(deployment_vm).to receive('model=').with(vm_model)}

      before { allow(job).to receive(:deployment).with(no_args).and_return(deployment_plan) }
      let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', model: deployment_model) }
      let(:deployment_model) { instance_double('Bosh::Director::Models::Deployment') }

      before { allow(job).to receive(:resource_pool).with(no_args).and_return(resource_pool) }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }

      before { allow(resource_pool).to receive(:stemcell).with(no_args).and_return(stemcell) }
      let(:stemcell) { instance_double('Bosh::Director::Models::Deployment', model: stemcell_model) }
      let(:stemcell_model) { instance_double('Bosh::Director::Models::Stemcell') }

      before { allow(resource_pool).to receive(:cloud_properties).with(no_args).and_return('fake-cloud-properties') }
      before { allow(resource_pool).to receive(:env).with(no_args).and_return('fake-env') }

      before { allow(instance).to receive(:network_settings).with(no_args).and_return('fake-network-settings') }
      before { allow(instance_model).to receive(:persistent_disk_cid).with(no_args).and_return(nil) }

      before { allow(AgentClient).to receive(:with_defaults).and_return(agent_client) }
      let(:agent_client) {
        instance_double('Bosh::Director::AgentClient',
          wait_until_ready: nil,
          update_settings: nil) }

      let(:vm_model) { Models::Vm.make }

      it 'tries to create vm when no persistent disk cid exists nor new disk cid provided' do
        expect(Bosh::Director::VmCreator).to receive(:create).with(
          deployment_model,
          stemcell_model,
          'fake-cloud-properties',
          'fake-network-settings',
          [],
          'fake-env',
        ).and_return(vm_model)

        vm_creator.create(nil)
      end

      it 'tries to create vm when no persistent disk cid exists and new disk cid provided' do
        expect(Bosh::Director::VmCreator).to receive(:create).with(
          deployment_model,
          stemcell_model,
          'fake-cloud-properties',
          'fake-network-settings',
          %w(fake-new-disk-cid),
          'fake-env',
        ).and_return(vm_model)

        vm_creator.create('fake-new-disk-cid')
      end

      it 'tries to create vm when persistent disk cid exists and new disk cid provided' do
        allow(instance_model).to receive(:persistent_disk_cid).
          with(no_args).and_return('fake-persistent-disk-cid')

        expect(Bosh::Director::VmCreator).to receive(:create).with(
          deployment_model,
          stemcell_model,
          'fake-cloud-properties',
          'fake-network-settings',
          %w(fake-persistent-disk-cid fake-new-disk-cid),
          'fake-env',
        ).and_return(vm_model)

        vm_creator.create('fake-new-disk-cid')
      end

      it 'tries to create vm when persistent disk cid exists and no disk cid provided' do
        allow(instance_model).to receive(:persistent_disk_cid).
          with(no_args).and_return('fake-persistent-disk-cid')

        expect(Bosh::Director::VmCreator).to receive(:create).with(
          deployment_model,
          stemcell_model,
          'fake-cloud-properties',
          'fake-network-settings',
          %w(fake-persistent-disk-cid),
          'fake-env',
        ).and_return(vm_model)

        vm_creator.create(nil)
      end

      context 'when vm creation succeeds' do
        before { allow(Bosh::Director::VmCreator).to receive(:create).and_return(vm_model) }

        it 'binds vm model to the instance' do
          expect(instance).to receive(:bind_to_vm_model).with(vm_model)

          vm_creator.create(nil)
        end

        it 'waits for new VM agent to respond' do
          expect(AgentClient).to receive(:with_defaults).with(vm_model.agent_id).and_return(agent_client)
          expect(agent_client).to receive(:wait_until_ready).with(no_args)
          vm_creator.create(nil)
        end

        it 'returns new vm model and agent client' do
          expect(vm_creator.create(nil)).to eq([vm_model, agent_client])
        end

        context 'when saving association between instance and the vm model fails' do
          before { allow(instance).to receive(:bind_to_vm_model).and_raise(error) }
          let(:error) { Exception.new }

          it 'raises association error after deleting created vm from the cloud and the database' do
            vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')

            expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
              with(instance, vm_model, cloud, logger).
              and_return(vm_deleter)

            expect(vm_deleter).to receive(:delete).with(no_args)

            expect { vm_creator.create(nil) }.to raise_error(error)
          end
        end

        context 'when vm agent fails to respond' do
          before { allow(agent_client).to receive(:wait_until_ready).and_raise(error) }
          let(:error) { Exception.new }

          it 'raises vm agent time out error after deleting created vm from the cloud and the database' do
            vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')

            expect(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
              with(instance, vm_model, cloud, logger).
              and_return(vm_deleter)

            expect(vm_deleter).to receive(:delete).with(no_args)

            expect { vm_creator.create(nil) }.to raise_error(error)
          end
        end
      end

      context 'when vm creation fails' do
        before { allow(Bosh::Director::VmCreator).to receive(:create).and_raise(error) }
        let(:error) { Exception.new }

        it 'does not save association between instance and the vm model' do
          expect {
            expect { vm_creator.create(nil) }.to raise_error(error)
          }.to_not change { instance_model.refresh.vm }.from(nil)
        end

        it 'does not delete vm' do
          expect(cloud).to_not receive(:delete_vm)
          expect { vm_creator.create(nil) }.to raise_error(error)
        end
      end

      context 'trusted certificate handling' do
        before do
          Bosh::Director::Config.trusted_certs=DIRECTOR_TEST_CERTS
          allow(Bosh::Director::VmCreator).to receive(:create).and_return(vm_model)

          vm_deleter = instance_double('Bosh::Director::InstanceUpdater::VmUpdater::VmDeleter')
          allow(InstanceUpdater::VmUpdater::VmDeleter).to receive(:new).
            with(instance, vm_model, cloud, logger).
            and_return(vm_deleter)
          allow(vm_deleter).to receive(:delete)
        end

        it 'should update the database with the new VM''s trusted certs' do
          vm_creator.create(nil)
          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1, agent_id: vm_model.agent_id).count).to eq(1)
        end

        it 'should not update the DB with the new certificates when the new vm fails to start' do
          expect(agent_client).to receive(:wait_until_ready).and_raise(RpcTimeout)

          begin
            vm_creator.create(nil)
          rescue RpcTimeout
            # expected
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end

        it 'should not update the DB with the new certificates when the update_settings method fails' do
          expect(agent_client).to receive(:update_settings).and_raise(RpcTimeout)

          begin
            vm_creator.create(nil)
          rescue RpcTimeout
            # expected
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end
      end
    end
  end

  describe InstanceUpdater::VmUpdater::VmDeleter do
    subject!(:vm_deleter) { described_class.new(instance, vm_model, cloud, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model) }
    let(:instance_model) { Models::Instance.make(vm: vm_model) }
    let(:vm_model) { Models::Vm.make }
    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#delete' do
      it 'tries to delete VM from the cloud' do
        expect(cloud).to receive(:delete_vm).with(vm_model.cid)
        vm_deleter.delete
      end

      context 'when delete from the cloud succeeds' do
        before { allow(cloud).to receive(:delete_vm).and_return(nil) }

        it 'deletes the VM from the database' do
          expect { vm_deleter.delete }.to change { Models::Vm.count }.by(-1)
        end

        it 'disassociates the VM from the instance in the database' do
          expect { vm_deleter.delete }.to change { instance_model.refresh.vm }.from(vm_model).to(nil)
        end
      end

      context 'when delete from the cloud fails' do
        before { allow(cloud).to receive(:delete_vm).and_raise(error) }
        let(:error) { Exception.new }

        it 'does not delete VM from the database' do
          expect {
            expect { vm_deleter.delete }.to raise_error(error)
          }.to_not change { Models::Vm.count }
        end

        it 'does not disassociate vm from the instance in the database' do
          expect {
            expect { vm_deleter.delete }.to raise_error(error)
          }.to_not change { instance_model.refresh.vm }.from(vm_model)
        end
      end
    end
  end

  describe InstanceUpdater::VmUpdater::DiskAttacher do
    subject(:disk_attacher) { described_class.new(instance, vm_model, agent_client, cloud, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model) }
    let(:instance_model) { instance_double('Bosh::Director::Models::Instance') }
    let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#attach' do
      context 'when disk cid is present' do
        before { allow(instance_model).to receive(:persistent_disk_cid).and_return('fake-disk-cid') }

        it 'tries to attach disk and then mount' do
          expect(cloud).to receive(:attach_disk).with('fake-vm-cid', 'fake-disk-cid').ordered
          expect(agent_client).to receive(:mount_disk).with('fake-disk-cid').ordered
          disk_attacher.attach
        end
      end

      context 'when disk cid is not present' do
        before { allow(instance_model).to receive(:persistent_disk_cid).and_return(nil) }

        it 'does not try to attach disk and then mount' do
          expect(cloud).to_not receive(:attach_disk)
          expect(agent_client).to_not receive(:mount_disk)
          disk_attacher.attach
        end
      end
    end
  end

  describe InstanceUpdater::VmUpdater::DiskDetacher do
    subject(:disk_detacher) { described_class.new(instance, vm_model, agent_client, cloud, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model) }
    let(:instance_model) { instance_double('Bosh::Director::Models::Instance') }
    let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#detach' do
      context 'when disk is not currently attached' do
        before { allow(agent_client).to receive(:list_disk).and_return([]) }
        it 'does not try to unmount and detach disk' do
          expect(agent_client).to_not receive(:unmount_disk)
          expect(cloud).to_not receive(:detach_disk)
          disk_detacher.detach
        end
      end

      context 'when disk is attached' do
        before { allow(agent_client).to receive(:list_disk).and_return(['fake-disk-cid']) }

        context 'when disk cid can be determined' do
          before { allow(instance_model).to receive(:persistent_disk_cid).and_return('fake-disk-cid') }

          it 'tries to unmount and then detach disk' do
            expect(agent_client).to receive(:unmount_disk).with('fake-disk-cid').ordered
            expect(cloud).to receive(:detach_disk).with('fake-vm-cid', 'fake-disk-cid').ordered
            disk_detacher.detach
          end
        end

        context 'when disk cid cannot be determined' do
          before { allow(instance_model).to receive(:persistent_disk_cid).and_return(nil) }
          before { allow(instance).to receive(:to_s).and_return('fake-instance') }

          it 'raises an error because director is in inconsistent state' do
            expect {
              disk_detacher.detach
            }.to raise_error(
              Bosh::Director::AgentUnexpectedDisk,
              "`fake-instance' VM has disk attached but it's not reflected in director DB"
            )
          end
        end
      end
    end
  end
end
