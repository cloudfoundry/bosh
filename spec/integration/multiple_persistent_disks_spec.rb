require 'spec_helper'

describe 'multiple persistent disks', type: :integration do
  with_reset_sandbox_before_each

  let(:small_disk) { {'type' => '1gb', 'name' =>  'small_disk'} }
  let(:large_disk) { {'type' => '4gb', 'name' =>  'large_disk'} }
  let(:additional_disk) { {'type' => '1gb', 'name' =>  'additional_disk'} }

  let(:manifest_hash) do
    hash = Bosh::Spec::Deployments.simple_manifest
    hash['jobs'].first['persistent_disks'] = [small_disk, large_disk]
    hash
  end

  let(:cloud_config_hash) do
    hash = Bosh::Spec::Deployments.simple_cloud_config
    hash['disk_types'] = [
      {
        'name' => '1gb',
        'disk_size' => 1024,
        'cloud_properties' => {'type' => 'gp2'}
      },
      {
        'name' => '4gb',
        'disk_size' => 4096,
        'cloud_properties' => {'type' => 'io1'}
      }
    ]
    hash
  end

  it 'should attach multiple persistent disks to the VM, add a disk, and delete a disk' do
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    vm_cid = director.instances.first.vm_cid
    disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    original_disk_cids = disk_infos.map { |disk_info| disk_info['disk_cid'] }

    manifest_hash['jobs'].first['persistent_disks'] = [small_disk, large_disk, additional_disk]
    deploy_simple_manifest(manifest_hash: manifest_hash)
    new_disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(new_disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    additional_disk_cids = new_disk_infos.map { |disk_info| disk_info['disk_cid'] }
    expect(additional_disk_cids).to include(*original_disk_cids)

    manifest_hash['jobs'].first['persistent_disks'] = [small_disk, large_disk]
    deploy_simple_manifest(manifest_hash: manifest_hash)

    down_scaled_disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(down_scaled_disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    expect(down_scaled_disk_infos.map { |disk_info| disk_info['disk_cid'] }).to eq(original_disk_cids)
  end
end
