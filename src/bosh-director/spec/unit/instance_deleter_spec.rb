require 'spec_helper'

module Bosh::Director
  describe InstanceDeleter do
    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:domain) { Models::Dns::Domain.make(name: 'bosh') }
    let(:cloud) { Config.cloud }
    let(:delete_job) {Jobs::DeleteDeployment.new('test_deployment', {})}
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}

    before do
      allow(delete_job).to receive(:task_id).and_return(task.id)
      allow(Config).to receive(:current_job).and_return(delete_job)
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
    end

    let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
    let(:dns_manager) { instance_double(DnsManager, delete_dns_for_instance: nil, cleanup_dns_records: nil, publish_dns_records: nil) }
    let(:options) { {} }
    let(:deleter) { InstanceDeleter.new(ip_provider, dns_manager, disk_manager, options) }
    let(:disk_manager) { DiskManager.new(logger) }

    describe '#delete_instance_plans' do
      let(:network_plan) { DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation) }

      let(:existing_vm) { Models::Vm.make(cid: 'fake-vm-cid') }
      let(:existing_instance) do
        instance = Models::Instance.make(deployment: deployment_model, uuid: 'my-uuid-1', job: 'fake-job-name', index: 5)
        instance.add_vm existing_vm
        instance.active_vm = existing_vm
        instance
      end

      let(:instance_plan) do
        DeploymentPlan::InstancePlan.new(
          existing_instance: existing_instance,
          instance: nil,
          network_plans: [network_plan],
          desired_instance: nil,
          skip_drain: true
        )
      end

      let(:instance_plans_to_delete) do
        instance_plans = []
        5.times { instance_plans << instance_plan }
        instance_plans
      end

      let(:instances_to_delete) do
        instances = []
        5.times { instances << instance_plan.instance }
        instances
      end

      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

      describe 'deleting instances' do
        before do
          allow(event_log_stage).to receive(:advance_and_track).and_yield
        end

        let(:network) { instance_double(DeploymentPlan::ManualNetwork, name: 'manual-network') }
        let(:reservation) do
          az = DeploymentPlan::AvailabilityZone.new('az', {})
          instance = DeploymentPlan::Instance.create_from_job(job, 5, {}, deployment_plan, 'started', az, logger)
          reservation = DesiredNetworkReservation.new(instance.model, network, '192.168.1.2', :dynamic)
          reservation.mark_reserved

          reservation
        end

        let(:deployment_model) { Models::Deployment.make(name: 'deployment-name') }
        let(:job) { DeploymentPlan::InstanceGroup.new(logger) }
        let(:deployment_plan) { instance_double(DeploymentPlan::Planner, ip_provider: ip_provider, model: deployment_model) }

        let(:stopper) { instance_double(Stopper) }
        before do
          allow(Stopper).to receive(:new).with(
              instance_plan,
              'stopped',
              Config,
              logger
            ).and_return(stopper)
        end

        let(:job_templates_cleaner) do
          job_templates_cleaner = instance_double('Bosh::Director::RenderedJobTemplatesCleaner')
          allow(RenderedJobTemplatesCleaner).to receive(:new).with(existing_instance, blobstore, logger).and_return(job_templates_cleaner)
          job_templates_cleaner
        end

        let(:persistent_disks) do
          disk = Models::PersistentDisk.make(disk_cid: 'fake-disk-cid-1')
          Models::Snapshot.make(persistent_disk: disk)
          [Models::PersistentDisk.make(disk_cid: 'instance-disk-cid'), disk]
        end

        before do
          persistent_disks.each { |disk| existing_instance.persistent_disks << disk }
        end

        it 'should delete the instances with the config max threads option' do
          allow(Config).to receive(:max_threads).and_return(5)
          pool = double('pool')
          expect(ThreadPool).to receive(:new).with(max_threads: 5).and_return(pool)
          expect(pool).to receive(:wrap).and_yield(pool)
          expect(pool).to receive(:process).exactly(5).times.and_yield

          5.times do |index|
            expect(deleter).to receive(:delete_instance_plan).with(
                instance_plans_to_delete[index],
                event_log_stage
              )
          end

          deleter.delete_instance_plans(instance_plans_to_delete, event_log_stage)
        end

        it 'should record deletion event' do
          expect(stopper).to receive(:stop)
          expect(cloud).to receive(:delete_vm).with(existing_instance.vm_cid)
          expect(ip_provider).to receive(:release).with(reservation)
          expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')

          expect {
            deleter.delete_instance_plans([instance_plan], event_log_stage)
          }.to change {
            Bosh::Director::Models::Event.count }.from(0).to(8)

          event_1 = Bosh::Director::Models::Event.order(:id).first
          expect(event_1.user).to eq(task.username)
          expect(event_1.action).to eq('delete')
          expect(event_1.object_type).to eq('instance')
          expect(event_1.object_name).to eq('fake-job-name/my-uuid-1')
          expect(event_1.task).to eq("#{task.id}")
          expect(event_1.deployment).to eq('deployment-name')
          expect(event_1.instance).to eq('fake-job-name/my-uuid-1')

          event_2 = Bosh::Director::Models::Event.order(:id).last
          expect(event_2.parent_id).to eq(1)
          expect(event_2.user).to eq(task.username)
          expect(event_2.action).to eq('delete')
          expect(event_2.object_type).to eq('instance')
          expect(event_2.object_name).to eq('fake-job-name/my-uuid-1')
          expect(event_2.task).to eq("#{task.id}")
          expect(event_2.deployment).to eq('deployment-name')
          expect(event_2.instance).to eq('fake-job-name/my-uuid-1')
        end

        it 'should record deletion event with error' do
          allow(stopper).to receive(:stop).and_raise(RpcTimeout)
          expect {
            deleter.delete_instance_plans([instance_plan], event_log_stage)
          }.to raise_error (RpcTimeout)
          event_2 = Bosh::Director::Models::Event.order(:id).last
          expect(event_2.error).to eq("Bosh::Director::RpcTimeout")
        end

        it 'should delete the instances with the respected max threads option' do
          pool = double('pool')
          expect(ThreadPool).to receive(:new).with(max_threads: 2).and_return(pool)
          expect(pool).to receive(:wrap).and_yield(pool)
          expect(pool).to receive(:process).exactly(5).times.and_yield

          5.times do |index|
            expect(deleter).to receive(:delete_instance_plan).with(
                instance_plans_to_delete[index], event_log_stage)
          end

          deleter.delete_instance_plans(instance_plans_to_delete, event_log_stage, max_threads: 2)
        end

        it 'drains, deletes snapshots, dns records, persistent disk, releases old reservations' do
          expect(stopper).to receive(:stop)
          expect(dns_manager).to receive(:delete_dns_for_instance).with(existing_instance)
          expect(dns_manager).to receive(:cleanup_dns_records)
          expect(dns_manager).to receive(:publish_dns_records)
          expect(cloud).to receive(:delete_vm).with(existing_instance.vm_cid)
          expect(ip_provider).to receive(:release).with(reservation)

          expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')

          job_templates_cleaner = instance_double('Bosh::Director::RenderedJobTemplatesCleaner')
          allow(RenderedJobTemplatesCleaner).to receive(:new).with(existing_instance, blobstore, logger).and_return(job_templates_cleaner)
          expect(job_templates_cleaner).to receive(:clean_all).with(no_args)
          expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)

          expect {
            deleter.delete_instance_plans([instance_plan], event_log_stage)
          }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
        end

        context 'when force option is passed in' do
          let(:options) { {force: true} }

          context 'when stopping fails' do
            before do
              allow(stopper).to receive(:stop).and_raise(RpcTimeout)
            end

            it 'deletes snapshots, persistent disk, releases old reservations' do
              expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)
              expect(dns_manager).to receive(:delete_dns_for_instance).with(existing_instance)
              expect(dns_manager).to receive(:cleanup_dns_records)
              expect(dns_manager).to receive(:publish_dns_records)
              expect(cloud).to receive(:delete_vm).with(existing_instance.vm_cid)
              expect(ip_provider).to receive(:release).with(reservation)

              expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')

              expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

              expect {
                deleter.delete_instance_plans([instance_plan], event_log_stage)
              }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
            end
          end

          context 'when deleting vm fails' do
            before do
              allow(cloud).to receive(:delete_vm).and_raise(
                  Bosh::Clouds::CloudError.new('Failed to create VM')
                )
            end

            it 'drains, deletes snapshots, persistent disk, releases old reservations' do
              expect(stopper).to receive(:stop)
              expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)
              expect(dns_manager).to receive(:delete_dns_for_instance).with(existing_instance)
              expect(dns_manager).to receive(:cleanup_dns_records)
              expect(dns_manager).to receive(:publish_dns_records)
              expect(ip_provider).to receive(:release).with(reservation)

              expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')

              expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

              expect {
                deleter.delete_instance_plans([instance_plan], event_log_stage)
              }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
            end
          end

          context 'when deleting dns fails' do
            before do
              allow(dns_manager).to receive(:delete_dns_for_instance).and_raise('failed')
              allow(dns_manager).to receive(:cleanup_dns_records)
              allow(dns_manager).to receive(:publish_dns_records)
            end

            it 'drains, deletes vm, snapshots, disks, releases old reservations' do
              expect(stopper).to receive(:stop)
              expect(cloud).to receive(:delete_vm).with(existing_instance.vm_cid)
              expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)
              expect(ip_provider).to receive(:release).with(reservation)

              expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')

              expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

              expect {
                deleter.delete_instance_plans([instance_plan], event_log_stage)
              }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
            end
          end

          context 'when cleaning templates fails' do
            before do
              allow(job_templates_cleaner).to receive(:clean_all).and_raise('failed')
            end

            it 'drains, deletes vm, snapshots, disks, releases old reservations' do
              expect(stopper).to receive(:stop)
              expect(cloud).to receive(:delete_vm).with(existing_instance.vm_cid)
              expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)
              expect(ip_provider).to receive(:release).with(reservation)

              expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')
              expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

              expect {
                deleter.delete_instance_plans([instance_plan], event_log_stage)
              }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
            end
          end
        end

        context 'when virtual_delete_vm option is passed in' do
          let(:options) { {virtual_delete_vm: true} }

          it 'deletes snapshots, persistent disk, releases old reservations, vm should not be deleted from cloud' do

            expect(stopper).to receive(:stop)
            expect(cloud).not_to receive(:delete_vm)

            expect(disk_manager).to receive(:delete_persistent_disks).with(existing_instance)
            expect(dns_manager).to receive(:delete_dns_for_instance).with(existing_instance)
            expect(dns_manager).to receive(:cleanup_dns_records)
            expect(dns_manager).to receive(:publish_dns_records)
            expect(ip_provider).to receive(:release).with(reservation)

            expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/my-uuid-1 (5)')
            expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

            expect {
              deleter.delete_instance_plans([instance_plan], event_log_stage)
            }.to change { Models::Instance.all.select{ |i| i.active_vm == existing_vm }.count}.from(1).to(0)
          end
        end
      end
    end
  end
end
