require 'spec_helper'
require 'fileutils'

describe 'deploy with resize_disk', type: :integration do

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
          'disk_size' => 123
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

  context 'with `enable_cpi_resize_disk` true' do
    with_reset_sandbox_before_each(enable_cpi_resize_disk: true)

    it 'resizes the disk with the CPI' do
      deploy_resize_deploy

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('resize_disk')
      expect(create_vm_invocations.count).to be > 0
    end

    context 'when CPI does not implement resize_disk' do

      it 'handles the exception' do
        current_sandbox.cpi.commands.make_resize_disk_to_raise_not_implemented

        deploy_resize_deploy

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('resize_disk')
        expect(create_vm_invocations.count).to be > 0
      end
    end
  end

  context 'with `enable_cpi_resize_disk` false' do
    with_reset_sandbox_before_each(enable_cpi_resize_disk: false)

    it 'does not use cpi resize' do
      deploy_resize_deploy

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('resize_disk')
      expect(create_vm_invocations.count).to be_zero
    end
  end
end

def deploy_resize_deploy
  prepare_for_deploy(cloud_config_hash: cloud_config)
  deploy_simple_manifest(manifest_hash: manifest)

  cloud_config['disk_types'][0]['disk_size'] = 234
  upload_cloud_config(cloud_config_hash: cloud_config)

  deploy_simple_manifest(manifest_hash: manifest)
end
