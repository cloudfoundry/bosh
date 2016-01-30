require 'spec_helper'

module Bosh::Director
  describe Jobs::AttachDisk do

    let(:deployment_name) { 'fake_deployment_name' }
    let(:disk_cid) { 'fake_disk_cid' }
    let(:job_name) { 'job_name' }
    let(:instance_id) { 'fake_instance_id' }

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }

      it 'enqueues an AttachDisk job' do
        expect(job_queue).to receive(:enqueue).with(
          'fake-username',
          Jobs::AttachDisk,
          "attach disk 'fake_disk_cid' to 'job_name/fake_instance_id'",
          [deployment_name, job_name, instance_id, disk_cid])
        Jobs::AttachDisk.enqueue('fake-username', deployment_name, job_name, instance_id, disk_cid, job_queue)
      end
    end

    let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, disk_cid) }

    describe '#perform' do
      let!(:instance_model) { Models::Instance.make(uuid: instance_id, job: job_name, vm_cid: vm_cid, state: 'detached') }
      let!(:deployment_model) do
        deployment_model = Models::Deployment.make(name: deployment_name)
        deployment_model.add_instance(instance_model)
        deployment_model
      end

      context 'when the instance is stopped hard' do
        let(:vm_cid) { nil }

        let!(:original_disk) do
          Models::PersistentDisk.make(
            disk_cid: 'original-disk-cid',
            instance_id: instance_model.id,
            active: true,
            size: 50)
        end

        it 'attaches the disk' do
          attach_disk_job.perform
          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'sets the disk size to 1 so it is migrated to the desired size next deploy' do
          attach_disk_job.perform
          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.first.size).to eq(1)
        end

        it 'marks the pre existing active persistent disk as inactive' do
          attach_disk_job.perform
          original_disk = Models::PersistentDisk[disk_cid: 'original-disk-cid']
          expect(instance_model.persistent_disks).to include(original_disk)
          expect(original_disk.active).to be(false)
        end

        it 'returns a message' do
          expect(attach_disk_job.perform).to eq("attached disk 'fake_disk_cid' to 'job_name/fake_instance_id' in deployment 'fake_deployment_name'")
        end

        context 'when the instance with the given instance id cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, 'bogus', disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/bogus' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given job name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, 'bogus', instance_id, disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'bogus/fake_instance_id' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given deployment name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new('bogus', job_name, instance_id, disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'bogus' was not found")
          end
        end

        context 'when the instance is not stopped --hard a.k.a. detached' do
          before do
            instance_model.update(state: 'started')
          end
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskInvalidInstanceState,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'fake_deployment_name' must be in 'bosh stopped --hard' state")
          end
        end
      end

      context 'when the job does not declare persistent disk' do
        let(:vm_cid) { 'fake-vm-cid' }
        it 'raise error' do
          expect { attach_disk_job.perform }.to raise_error(AttachDiskNoPersistentDisk, "Job 'job_name' is not configured with a persistent disk")
        end
      end
    end
  end
end
