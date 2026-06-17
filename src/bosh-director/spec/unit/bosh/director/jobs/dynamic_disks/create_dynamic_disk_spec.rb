require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::CreateDynamicDisk do
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_pool_name) { 'fake-disk-pool-name' }
    let(:disk_cloud_properties) { { 'fake-disk-cloud-property-key' => 'fake-disk-cloud-property-value' } }
    let(:disk_size) { 1000 }
    let(:metadata) { { 'fake-key' => 'fake-value' } }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:instance) { FactoryBot.create(:models_instance) }
    let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }

    let(:task_result) { TaskDBWriter.new(:result_output, task.id) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    def parsed_task_result
      JSON.parse(Models::Task.first(id: 42).result_output)
    end

    let(:create_dynamic_disk_job) { Jobs::DynamicDisks::CreateDynamicDisk.new(instance.uuid, disk_name, disk_pool_name, disk_size, metadata) }

    let!(:cloud_config) do
      FactoryBot.create(:models_config_cloud, content: YAML.dump(
        SharedSupport::DeploymentManifestHelper.simple_cloud_config.merge(
          'disk_types' => [
            { 'name' => disk_pool_name,
              'disk_size' => 1024,
              'cloud_properties' => disk_cloud_properties },
          ],
        ),
      ))
    end
    let(:cloud_factory) { instance_double(CloudFactory, get: cloud) }

    before do
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(Config).to receive(:result).and_return(task_result)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(false)
      allow(create_dynamic_disk_job).to receive(:task_id).and_return(task.id)
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :create_dynamic_disk }
      let(:queue) { :dynamic_disks }
      it_behaves_like 'a DelayedJob job'
    end

    describe '#perform' do
      context 'when disk does not exist' do
        it 'creates the disk without attaching it to a VM' do
          expected_cloud_properties = disk_cloud_properties.merge('name' => disk_name)
          expect(cloud).to receive(:create_disk).with(disk_size, expected_cloud_properties, vm.cid).and_return(disk_cid)

          result = create_dynamic_disk_job.perform

          expect(result).to eq("created disk `#{disk_name}` in deployment `#{instance.deployment.name}`")
          expect(parsed_task_result).to eq({ 'disk_cid' => disk_cid })

          model = Models::DynamicDisk.where(disk_cid: disk_cid).first
          expect(model).not_to be_nil
          expect(model.name).to eq(disk_name)
          expect(model.size).to eq(disk_size)
          expect(model.deployment_id).to eq(instance.deployment.id)
          expect(model.disk_pool_name).to eq(disk_pool_name)
          expect(model.cpi).to eq(vm.cpi)
          expect(model.vm).to be_nil
        end
      end

      context 'when disk already exists in the database' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: vm.instance.deployment,
            disk_pool_name: disk_pool_name,
          )
        end

        it 'returns the existing disk without calling create_disk' do
          expect(cloud).not_to receive(:create_disk)

          result = create_dynamic_disk_job.perform

          expect(result).to eq("created disk `#{disk_name}` in deployment `#{instance.deployment.name}`")
          expect(parsed_task_result).to eq({ 'disk_cid' => disk_cid })
        end
      end

      context 'when metadata is provided and CPI supports set_disk_metadata' do
        it 'sets disk metadata after creation' do
          expected_cloud_properties = disk_cloud_properties.merge('name' => disk_name)
          expect(cloud).to receive(:create_disk).with(disk_size, expected_cloud_properties, vm.cid).and_return(disk_cid)
          expect(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(true)
          expect(cloud).to receive(:set_disk_metadata).with(
            disk_cid,
            hash_including('fake-key' => 'fake-value'),
          )

          create_dynamic_disk_job.perform
        end
      end

      context 'when disk_pool_name cannot be found in cloud config' do
        let!(:cloud_config) do
          FactoryBot.create(:models_config_cloud, content: YAML.dump(
            SharedSupport::DeploymentManifestHelper.simple_cloud_config.merge(
              'disk_types' => [
                { 'name' => 'different-disk-type',
                  'disk_size' => 1024,
                  'cloud_properties' => {} },
              ],
            ),
          ))
        end

        it 'raises an error' do
          expect { create_dynamic_disk_job.perform }.to raise_error("Could not find disk pool by name `#{disk_pool_name}`")
        end
      end

      context 'when instance cannot be found' do
        let(:create_dynamic_disk_job) { Jobs::DynamicDisks::CreateDynamicDisk.new('unknown-instance-id', disk_name, disk_pool_name, disk_size, metadata) }

        it 'raises an error' do
          expect { create_dynamic_disk_job.perform }.to raise_error("instance `unknown-instance-id` not found")
        end
      end

      context 'when there is no active VM for the instance' do
        let(:vm) { FactoryBot.create(:models_vm, instance: instance, active: false) }

        it 'raises an error' do
          expect { create_dynamic_disk_job.perform }.to raise_error("no active vm found for instance `#{instance.uuid}`")
        end
      end
    end
  end
end
