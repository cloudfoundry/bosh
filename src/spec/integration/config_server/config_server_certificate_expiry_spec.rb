require 'spec_helper'

describe 'using director with config server and deployments having variables', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

  let(:director_name) { current_sandbox.director_name }

  let(:client_env) do
    {
      'BOSH_CLIENT' => 'test',
      'BOSH_CLIENT_SECRET' => 'secret',
      'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s,
    }
  end

  let(:config_server_helper) { IntegrationSupport::ConfigServerHelper.new(current_sandbox, logger) }

  let(:cloud_config) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = [
      '192.168.1.10',
      '192.168.1.11',
      '192.168.1.12',
      '192.168.1.13',
    ]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
      'name' => 'dynamic-network',
      'type' => 'dynamic',
      'subnets' => [{ 'az' => 'z1' }],
    }

    cloud_config_hash
  end

  let(:provider_job_name) { 'http_server_with_provides' }
  let(:my_instance_group) do
    instance_group_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'my_instance_group',
      jobs: [
        {
          'name' => provider_job_name,
          'release' => 'bosh-release',
          'properties' => { 'name_space' => { 'fibonacci' => '((/bob))' } },
        },
        {
          'name' => 'http_proxy_with_requires',
          'release' => 'bosh-release',
          'properties' => { 'listen_port' => 9999 },
        },
      ],
      instances: 1,
    )
    instance_group_spec['azs'] = ['z1']
    instance_group_spec
  end
  let(:manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['instance_groups'] = [my_instance_group]
    manifest
  end
  let(:deployment_name) { manifest['name'] }

  before do
    upload_links_release(bosh_runner_options: { include_credentials: false, env: client_env})
    upload_stemcell(include_credentials: false, env: client_env)

    upload_cloud_config(cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
  end

  context 'when certificates are defined in the variables section' do
    before do
      manifest['variables'] = [
        {
          'name' => '/bob',
          'type' => 'password',
        },
        {
          'name' => '/joeCA',
          'type' => 'certificate',
          'options' => {
            'is_ca' => true,
            'common_name' => 'Joe CA',
          },
        },
        {
          'name' => '/JoeService',
          'type' => 'certificate',
          'options' => {
            'ca' => '/joeCA',
          },
        },
      ]

      deploy_simple_manifest(manifest_hash: manifest, cloud_config_hash: cloud_config,
                             include_credentials: false, env: client_env)
    end

    it 'records the expiry of all generated certificates' do
      result = bosh_runner.run(
        "curl /deployments/#{deployment_name}/certificate_expiry",
        json: true, environment_name: current_sandbox.director_url, env: client_env, include_credentials: false,
      )
      certificate_expiry = JSON.parse(JSON.parse(result)['Blocks'][0])

      expect(certificate_expiry.count).to eq(2)
      expect(certificate_expiry[0]['expiry_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      expect(certificate_expiry[0]['days_left']).to eq(364)
      expect(certificate_expiry[0]['name']).to eq('/joeCA')
      expect(certificate_expiry[0]['id']).to eq('1')

      expect(certificate_expiry[1]['expiry_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      expect(certificate_expiry[1]['days_left']).to eq(364)
      expect(certificate_expiry[1]['name']).to eq('/JoeService')
      expect(certificate_expiry[1]['id']).to eq('2')
    end

    context 'when certificates are updated during redeploy' do
      before do
        manifest['variables'] <<
          {
            'name' => 'FredService',
            'type' => 'certificate',
            'options' => {
              'ca' => '/joeCA',
            },
          }
      end

      it 'should update the expiry details of changed certificates' do
        deploy_simple_manifest(manifest_hash: manifest, cloud_config_hash: cloud_config,
                               include_credentials: false, env: client_env)
        result = bosh_runner.run(
          "curl /deployments/#{deployment_name}/certificate_expiry",
          json: true, environment_name: current_sandbox.director_url, env: client_env, include_credentials: false,
        )
        certificate_expiry = JSON.parse(JSON.parse(result)['Blocks'][0])

        expect(certificate_expiry.count).to eq(3)
        expect(certificate_expiry[2]['expiry_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
        expect(certificate_expiry[2]['days_left']).to eq(364)
        expect(certificate_expiry[2]['name']).to eq('/TestDirector/simple/FredService')
        expect(certificate_expiry[2]['id']).to eq('3')

        expect(certificate_expiry[0]['name']).to eq('/joeCA')
        expect(certificate_expiry[1]['name']).to eq('/JoeService')
      end
    end

    context 'when certificate is specified as absolute path (from different deployment)' do
      let(:my_instance_group_2) do
        instance_group_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'my_instance_group',
          jobs: [
            {
              'name' => provider_job_name,
              'release' => 'bosh-release',
              'properties' => { 'name_space' => { 'fibonacci' => '((/JoeService))' } },
            },
            { 'name' => 'http_proxy_with_requires', 'release' => 'bosh-release' },
          ],
          instances: 1,
        )
        instance_group_spec['azs'] = ['z1']
        instance_group_spec
      end

      let(:deployment_name_2) { 'complex' }
      let(:deploy_2_manifest) { Bosh::Director::DeepCopy.copy(manifest) }

      before do
        deploy_2_manifest['name'] = deployment_name_2
        deploy_2_manifest['instance_groups'] = [my_instance_group_2]
        deploy_2_manifest.delete('variables')

        deploy_simple_manifest(manifest_hash: manifest, cloud_config_hash: cloud_config,
                               include_credentials: false, env: client_env)
      end

      it 'should update the certificate expiry list for deployment' do
        deploy_simple_manifest(manifest_hash: deploy_2_manifest, cloud_config_hash: cloud_config,
                               include_credentials: false, env: client_env)

        result = bosh_runner.run(
          "curl /deployments/#{deployment_name_2}/certificate_expiry",
          json: true, environment_name: current_sandbox.director_url, env: client_env, include_credentials: false,
        )
        certificate_expiry = JSON.parse(JSON.parse(result)['Blocks'][0])

        expect(certificate_expiry.count).to eq(1)
        expect(certificate_expiry[0]['expiry_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
        expect(certificate_expiry[0]['days_left']).to eq(364)
        expect(certificate_expiry[0]['name']).to eq('/JoeService')
        expect(certificate_expiry[0]['id']).to eq('2')
      end
    end
  end
end
