require_relative '../../../gocli/spec_helper.rb'

# Make sure to enable the test suite below when you want to generate blobstore and db dumps for mysql and postgresql
xdescribe 'Links', type: :integration do
  with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false})

  let(:manifest_hash) do
    {
      'name' => 'simple',
      'releases' => [{'name' => 'bosh-release', 'version' => 'latest'}],
      'update' => {
        'canaries' => 2,
        'canary_watch_time' => 4000,
        'max_in_flight' => 1,
        'update_watch_time' => 20
      },
      'instance_groups' => [{
        'name' => 'ig_provider',
        'jobs' => [{
          'name' => 'provider',
          'provides' => {
            'provider' => { 'as' => 'provider_link', 'shared' => true}
          },
          'properties' => {
            'a' => '1',
            'b' => '2',
            'c' => '3',
          }
        }],
        'instances' => 1,
        'networks' => [{'name' => 'private'}],
        'vm_type' => 'small',
        'persistent_disk_type' => 'small',
        'azs' => ['z1'],
        'stemcell' => 'default'
      }],
      'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
    }
  end

  let(:cloud_config) do
    {
      'azs' => [{'name' => 'z1'}],
      'vm_types' => [{'name' => 'small'}],
      'disk_types' => [{
        'name' => 'small',
        'disk_size' => 3000
      }],
      'networks' => [{
        'name' => 'private',
        'type' => 'manual',
        'subnets' => [
          {
            'range' => '10.10.0.0/24',
            'gateway' => '10.10.0.1',
            'az' => 'z1',
            'static' => ['10.10.0.62'],
            'dns' => ['10.10.0.2'],
          }
        ]
      }],
      'compilation' => {
        'workers' => 1,
        'reuse_compilation_vms' => true,
        'az' => 'z1',
        'vm_type' => 'small',
        'network' => 'private'
      }
    }
  end

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  before do
    upload_links_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  it 'deploys a simple deployment so we can take the database and blobstore dump' do
    deploy_simple_manifest(manifest_hash: manifest_hash)
    bosh_runner.run('-d simple stop --hard ')
    # sleep 60 * 3
  end
end
