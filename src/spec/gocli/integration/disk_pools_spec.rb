require_relative '../spec_helper'

describe 'disk pools', type: :integration do
  with_reset_sandbox_before_each

  def deploy_with_disk_pool(disk_size, cloud_properties={})
    manifest_hash = Bosh::Spec::Deployments.legacy_manifest
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'fast_disks'
    manifest_hash['disk_pools'] = [
      {
        'name' => 'fast_disks',
        'disk_size' => disk_size,
        'cloud_properties' => cloud_properties
      }
    ]

    deploy_from_scratch(manifest_hash: manifest_hash, legacy: true)
  end

  it 'allows specifying a disk_pool' do
    deploy_with_disk_pool(3000)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows specifying persistent_disk size on a job' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['persistent_disk'] = 3000

    deploy_from_scratch(manifest_hash: manifest_hash)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows NOT specifying a persistent_disk' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first.delete('persistent_disk')
    deploy_from_scratch(manifest_hash: manifest_hash)

    director.instances.each do |instance|
      expect(instance.get_state['persistent_disk']).to eq(0)
    end
  end

  context 'with existing disk pool with cloud_properties' do
    let(:cloud_properties) { {'type' => 'gp2'} }
    before { deploy_with_disk_pool(disk_size, cloud_properties) }

    context 'when disk size is 0' do
      let(:disk_size) { 0 }

      context 'when cloud_properties were not changed' do
        it 'does not update the job' do
          expect(deploy_with_disk_pool(disk_size, cloud_properties)).to_not include('Updating instance foobar: ')

          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end

      context 'when cloud_properties were changed' do
        let(:cloud_properties) { {'type' => 'ssd'} }

        it 'does not update the job' do
          expect(deploy_with_disk_pool(disk_size, cloud_properties)).to_not include('Updating instance foobar: ')

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
          expect(deploy_with_disk_pool(disk_size, cloud_properties)).to_not include('Updating instance foobar: ')

          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end

      context 'when cloud_properties were changed' do
        it 'does update the job' do
          expect(deploy_with_disk_pool(disk_size, {'type' => 'ssd'})).to include('Updating instance foobar: ')

          director.instances.each do |instance|
            expect(instance.get_state['persistent_disk']).to eq(disk_size)
          end
        end
      end
    end
  end
end
