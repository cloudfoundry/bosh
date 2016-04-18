require 'spec_helper'
require 'fileutils'

describe 'deploy after db migrations', type: :integration do
  insert_data_migration_file_before_all
  with_reset_sandbox_before_each
  delete_data_migration_file_after_all

  def upload_release
    bosh_runner.run_in_dir("upload release #{File.join(ASSETS_DIR, 'valid_release.tgz')}", ASSETS_DIR)
  end

  before do
    target_and_login
    upload_release
    upload_stemcell
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]

    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['networks'] << {
        'name' => 'dynamic-network',
        'type' => 'dynamic',
        'subnets' => [{'az' => 'z1'}]
    }

    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['resource_pools'] = [{
         'name' => 'b',
         'cloud_properties' => {},
         'stemcell' => {
             'name' => 'ubuntu-stemcell',
             'version' => '1',
         },
         'env' => {
             'bosh' => {
                 'password' => 'foobar'
             }
         }
     }]

    cloud_config_hash
  end

  let(:cleaner_job_spec) do
    job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'cleaner',
        templates: [{'name' => 'cleaner'}],
        instances: 1,
    )
    job_spec['azs'] = ['z1']
    job_spec['resource_pool'] = 'b'
    job_spec
  end

  let(:manifest_hash ) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'] = [{'name' => 'appcloud', 'version' => 'latest'}]
    manifest_hash['jobs'] = [cleaner_job_spec]
    manifest_hash
  end

  context 'auto deploy' do
    xit 'deploys a simple manifest and cloud config after running migrations on a pre-seeded database' do
      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end
  end
end

