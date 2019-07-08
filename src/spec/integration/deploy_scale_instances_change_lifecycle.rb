require_relative '../spec_helper'
require 'fileutils'

describe 'deploy scaling instances and lifecycle', type: :integration do
  with_reset_sandbox_before_each

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

  let(:manifest_initial) do
    {
      'name' => 'simple',
      'releases' => [{ 'name' => 'bosh-release', 'version' => 'latest' }],
      'stemcells' => [{ 'alias' => 'ubuntu', 'os' => 'toronto-os', 'version' => 'latest' }],
      'instance_groups' => [{
        'name' => 'foobar',
        'instances' => 5,
	'lifecycle' => 'service',
        'vm_type' => 'tiny',
        'stemcell' => 'ubuntu',
        'networks' => [{ 'name' => 'default' }],
        'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
      }],
      'update' => {
        'canaries' => 1,
        'max_in_flight' => 10,
        'canary_watch_time' => '1000-30000',
        'update_watch_time' => '1000-30000'
      }
    }
  end

  let(:manifest_scaled) do
    {
      'name' => 'simple',
      'releases' => [{ 'name' => 'bosh-release', 'version' => 'latest' }],
      'stemcells' => [{ 'alias' => 'ubuntu', 'os' => 'toronto-os', 'version' => 'latest' }],
      'instance_groups' => [{
        'name' => 'foobar',
        'instances' => 1,
	'lifecycle' => 'errand',
        'vm_type' => 'tiny',
        'stemcell' => 'ubuntu',
        'networks' => [{ 'name' => 'default' }],
        'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
      }],
      'update' => {
        'canaries' => 1,
        'max_in_flight' => 10,
        'canary_watch_time' => '1000-30000',
        'update_watch_time' => '1000-30000'
      }
    }
  end

  it 'does not try to delete previously deleted instances' do
    upload_stemcell
    bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    upload_cloud_config(cloud_config_hash: cloud_config)

    deploy_simple_manifest(manifest_hash: manifest_initial)
    deploy_simple_manifest(manifest_hash: manifest_scaled)

    expect(director.instances.length).to eq(1)
  end
end
