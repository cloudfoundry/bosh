require_relative '../spec_helper'

describe 'disk types', type: :integration do
  with_reset_sandbox_before_each

  def deploy_with_disk_type(disk_size, cloud_properties={})
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['disk_types'] = [
      {
        'name' => 'fast_disks',
        'disk_size' => disk_size,
        'cloud_properties' => cloud_properties
      }
    ]

    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['persistent_disk_type'] = 'fast_disks'

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
  end

  it 'allows specifying a disk_type' do
    deploy_with_disk_type(3000)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows specifying persistent_disk size on a job' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['persistent_disk'] = 3000
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows NOT specifying a persistent_disk' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first.delete('persistent_disk')
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(0)
    end
  end

  context 'with existing disk type with cloud_properties' do
    let(:cloud_properties) { {'type' => 'gp2'} }
    before { deploy_with_disk_type(disk_size, cloud_properties) }

    context 'when disk size is 0' do
      let(:disk_size) { 0 }

      context 'when cloud_properties were not changed' do
        it 'does not update the job' do
          old_disk_cids = director.instances.map(&:disk_cids)
          deploy_with_disk_type(disk_size, cloud_properties)

          director.instances.each do |instance|
            expect(old_disk_cids).to include(instance.disk_cids)
          end

          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end

      context 'when cloud_properties were changed' do
        let(:cloud_properties) { {'type' => 'ssd'} }

        it 'does not update the job' do
          old_disk_cids = director.instances.map(&:disk_cids)
          deploy_with_disk_type(disk_size, cloud_properties)

          director.instances.each do |instance|
            expect(old_disk_cids).to include(instance.disk_cids)
          end
          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end
    end

    context 'when disk size is greater than 0' do
      let(:disk_size) { 1 }

      context 'when cloud_properties were not changed' do
        it 'does not update the job' do
          old_disk_cids = director.instances.map(&:disk_cids)
          deploy_with_disk_type(disk_size, cloud_properties)

          director.instances.each do |instance|
            expect(old_disk_cids).to include(instance.disk_cids)
          end

          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end

      context 'when cloud_properties were changed' do
        it 'does update the job' do
          old_disk_cids = director.instances.map(&:disk_cids)

          output = deploy_with_disk_type(disk_size, {'type' => 'ssd'})
          expect(output).to include('Updating instance foobar')
          expect(output).to include('Succeeded')

          director.instances.each do |instance|
            expect(old_disk_cids).to_not include(instance.disk_cids)
          end
          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end
    end
  end
end
