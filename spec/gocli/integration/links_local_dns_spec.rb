require_relative '../spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false})

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
        'name' => 'manual-network',
        'type' => 'manual',
        'subnets' => [
            {'range' => '10.10.0.0/24',
             'gateway' => '10.10.0.1',
             'az' => 'z1'}]
    }

    cloud_config_hash
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when job requires link' do

    let(:api_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'my_api',
          templates: [{'name' => 'api_server', 'consumes' => {
                  'db' => {'from' => 'db'}
              }}],
          instances: 1
      )
      job_spec['networks'] = [{ 'name' => 'manual-network'}]
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:mysql_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'mysql',
          templates: [{'name' => 'database'}],
          instances: 1,
          static_ips: ['192.168.1.10']
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] = [{ 'name' => 'manual-network'}]
      job_spec
    end

    let(:manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['jobs'] = [api_job_spec, mysql_job_spec]
      manifest
    end

    context 'when link is provided' do
      context 'when network is manual and local_dns is enabled' do
        it 'uses UUID dns names in templates' do
          deploy_simple_manifest(manifest_hash: manifest)
          instances = director.instances
          api_instance = director.find_instance(instances, 'my_api', '0')
          mysql_0_instance = director.find_instance(instances, 'mysql', '0')
          template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))
          addresses = template['databases']['main'].map do |elem|
            elem['address']
          end
          expect(addresses).to eq(["#{mysql_0_instance.id}.mysql.manual-network.simple.bosh"])
        end
      end
    end
  end
end
