require 'spec_helper'

describe 'multiple persistent disks', type: :integration do
  with_reset_sandbox_before_each

  it 'should attach multiple persistent disks to the VM' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['disk_types'] = [
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

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['persistent_disks'] = [
      {'type' => '1gb', 'name' =>  'small_disk'},
      {'type' => '4gb', 'name' =>  'large_disk'}
    ]

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    instances = director.instances
    disk_infos = current_sandbox.cpi.attached_disk_infos(instances.first.vm_cid)

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
  end
end
