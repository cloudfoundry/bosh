require 'spec_helper'
require 'fileutils'

describe 'deploy with update_disk', type: :integration do

  let(:cloud_config) do
    {
      'networks' => [{
        'name' => 'default',
        'type' => 'dynamic'
      }],
      'vm_types' => [{
        'name' => 'tiny'
      }],
      'disk_types' => [{
          'name' => 'disk_a',
          'disk_size' => 1024,
          'cloud_properties' => {
            'foo' => 'bar'
          }
      }],
      'compilation' => {
        'workers' => 1,
        'reuse_compilation_vms' => true,
        'vm_type' => 'tiny',
        'network' => 'default'
      }
    }
  end

  let(:manifest) do
    {
      'name' => 'simple',
      'releases' => [{ 'name' => 'bosh-release', 'version' => 'latest' }],
      'stemcells' => [{ 'alias' => 'ubuntu', 'os' => 'toronto-os', 'version' => 'latest' }],
      'instance_groups' => [{
        'name' => 'foobar',
        'instances' => 1,
        'vm_type' => 'tiny',
        'stemcell' => 'ubuntu',
        'networks' => [{ 'name' => 'default' }],
        'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
        'persistent_disk_type' => 'disk_a'
      }],
      'update' => {
        'canaries' => 1,
        'max_in_flight' => 10,
        'canary_watch_time' => '1000-30000',
        'update_watch_time' => '1000-30000'
      }
    }
  end

  context 'with `enable_cpi_update_disk` true' do
    with_reset_sandbox_before_each(enable_cpi_update_disk: true)

    it 'updates the disk with the iaas native update method' do
      deploy_update_deploy

      invocations = current_sandbox.cpi.invocations_for_method('update_disk')
      inputs = invocations.first[:inputs]

      expect(invocations.count).to eq(1)
      expect(inputs['new_size']).to eq(2048)
      expect(inputs['cloud_properties']).to eq({'foo'=>'baz'})

      vm_cid = director.instances.first.vm_cid
      disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
      expect(disk_infos).to match([
        {
          'size' => 2048,
          'cloud_properties' => {'foo' => 'baz'},
          'vm_locality' => String,
          'disk_cid' => String,
          'device_path' => 'attached'
        }
      ])
    end

    context 'when CPI does not implement update_disk' do

      it 'handles the exception' do
        current_sandbox.cpi.commands.make_update_disk_to_raise_not_implemented

        expect { deploy_update_deploy }.not_to raise_error

        invocations = current_sandbox.cpi.invocations_for_method('update_disk')
        expect(invocations.count).to eq(1)
      end
    end
  end

  context 'with `enable_cpi_update_disk` false' do
    with_reset_sandbox_before_each(enable_cpi_update_disk: false)

    it 'does not use the iaas native update' do
      deploy_update_deploy

      invocations = current_sandbox.cpi.invocations_for_method('update_disk')
      expect(invocations.count).to be_zero
    end
  end
end

def deploy_update_deploy
  # Deploy with initial disk size and cloud properties
  cloud_config['disk_types'][0]['disk_size'] = 1024
  cloud_config['disk_types'][0]['cloud_properties']['foo'] = 'bar'
  prepare_for_deploy(cloud_config_hash: cloud_config)
  deploy_simple_manifest(manifest_hash: manifest)

  # Update disk size and cloud properties
  cloud_config['disk_types'][0]['disk_size'] = 2048
  cloud_config['disk_types'][0]['cloud_properties']['foo'] = 'baz'
  upload_cloud_config(cloud_config_hash: cloud_config)
  deploy_simple_manifest(manifest_hash: manifest)
end
