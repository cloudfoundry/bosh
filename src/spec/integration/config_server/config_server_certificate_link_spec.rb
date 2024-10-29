require 'spec_helper'

describe 'using director with config server and deployments having links', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir(
      'create-release --force',
      ClientSandbox.links_release_dir,
      include_credentials: false,
      env: client_env,
    )
    bosh_runner.run_in_dir(
      'upload-release',
      ClientSandbox.links_release_dir,
      include_credentials: false,
      env: client_env,
    )
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  def get(path, params)
    director_url = build_director_api_url(path, params)
    JSON.parse(send_request('GET', director_url, nil).body)
  end

  def send_request(verb, url, body)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = Bosh::Dev::Sandbox::UaaService::ROOT_CERT
    http.send_request(verb, url.request_uri, body, {'Authorization' => config_server_helper.auth_header, 'Content-Type' => 'application/json'})
  end

  let(:director_name) { current_sandbox.director_name }

  let(:deployment_name) { 'simple' }

  let(:client_env) do
    {
      'BOSH_CLIENT' => 'test',
      'BOSH_CLIENT_SECRET' => 'secret',
      'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s,
    }
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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

  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }

  before do
    upload_links_release
    upload_stemcell(include_credentials: false, env: client_env)

    upload_cloud_config(cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
  end

  let(:variables) do
    [
      {
        'name' => 'bbs_ca',
        'type' => 'certificate',
        'options' => { 'is_ca' => true },
      },
      {
        'name' => 'bbs',
        'type' => 'certificate',
        'consumes' => { 'alternative_name' => { 'from' => 'http_endpoint' } },
        'options' => { 'ca' => 'bbs_ca', 'alternative_names' => ['127.0.0.1'] },
      }
    ]
  end

  let(:deployment_manifest) do
    Bosh::Spec::NetworkingManifest.deployment_manifest.tap do |manifest|
      manifest['name'] = deployment_name
      manifest['instance_groups'] = instance_groups
    end
  end

  let(:provider_job) do
    {
      'name' => 'provider',
      'release' => 'bosh-release',
      'provides' => {
        'my_endpoint' => {
          'as' => 'http_endpoint',
        },
      },
      'custom_provider_definitions' => [
        {
          'name' => 'my_endpoint',
          'type' => 'address',
          'properties' => %w[b nested],
        },
      ],
      'properties' => { 'b' => 'bar', 'nested' => { 'three' => 'foo' } },
    }
  end

  let(:instance_groups) do
    [Bosh::Spec::Deployments.simple_instance_group(
      name: 'my_instance_group',
      jobs: [provider_job],
      instances: 1,
    ).tap do |ig|
      ig['azs'] = ['z1']
    end]
  end

  it 'generates the certificate with the dns record as an alternative name' do
    deployment_manifest['variables'] = variables

    deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

    cert = config_server_helper.get_value(prepend_namespace('bbs'))
    cert = OpenSSL::X509::Certificate.new(cert['certificate'])
    subject_alt_name = cert.extensions.find { |e| e.oid == 'subjectAltName' }

    alternative_names = subject_alt_name.value.split(', ').map do |names|
      names.split(':', 2)[1]
    end

    expect(alternative_names).to match_array(['127.0.0.1', 'q-s0.my-instance-group.a.simple.bosh'])
  end

  context 'when the runtime config has variable which consumes' do
    let(:runtime_config) do
      Bosh::Spec::Deployments.simple_runtime_config.tap do |config|
        config['variables'] = variables
        config['releases'] = []
        config['addons'] = []
      end
    end

    before do
      upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)
    end

    it 'generates the certificate with the dns record as an alternative name' do
      deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

      cert = config_server_helper.get_value(prepend_namespace('bbs'))
      cert = OpenSSL::X509::Certificate.new(cert['certificate'])
      subject_alt_name = cert.extensions.find { |e| e.oid == 'subjectAltName' }

      alternative_names = subject_alt_name.value.split(', ').map do |names|
        names.split(':', 2)[1]
      end

      expect(alternative_names).to match_array(['127.0.0.1', 'q-s0.my-instance-group.a.simple.bosh'])
    end

    context 'when there is a common name specified' do
      let(:variables) do
        [
          {
            'name' => 'bbs_ca',
            'type' => 'certificate',
            'options' => { 'is_ca' => true },
          },
          {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => { 'common_name' => { 'from' => 'http_endpoint' } },
            'options' => { 'ca' => 'bbs_ca', 'alternative_names' => ['127.0.0.1'] },
          },
        ]
      end

      it 'generates a certificate with a common name' do
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

        cert = config_server_helper.get_value(prepend_namespace('bbs'))
        cert = OpenSSL::X509::Certificate.new(cert['certificate'])
        subject = cert.subject.to_a
        common_name = subject.select { |name, _, _| name == 'CN' }.first[1]
        expect(common_name).to eq('q-s0.my-instance-group.a.simple.bosh')

        subject_alt_name = cert.extensions.find { |e| e.oid == 'subjectAltName' }

        alternative_names = subject_alt_name.value.split(', ').map do |names|
          names.split(':', 2)[1]
        end
        expect(alternative_names).to match_array(['127.0.0.1'])
      end
    end

    context 'when wildcard is specified in both common name and alternative_name' do
      let(:variables) do
        [
          {
            'name' => 'bbs_ca',
            'type' => 'certificate',
            'options' => { 'is_ca' => true },
          },
          {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => {
              'common_name' => {
                'from' => 'http_endpoint',
                'properties' => { 'wildcard' => true },
              },
              'alternative_name' => {
                'from' => 'http_endpoint',
                'properties' => { 'wildcard' => true },
              },
            },
            'options' => { 'ca' => 'bbs_ca', 'alternative_names' => ['127.0.0.1'] },
          },
        ]
      end

      it 'generates a certificate with a common name' do
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

        cert = config_server_helper.get_value(prepend_namespace('bbs'))
        cert = OpenSSL::X509::Certificate.new(cert['certificate'])
        subject = cert.subject.to_a
        common_name = subject.select { |name, _, _| name == 'CN' }.first[1]
        expect(common_name).to eq('*.my-instance-group.a.simple.bosh')

        subject_alt_name = cert.extensions.find { |e| e.oid == 'subjectAltName' }

        alternative_names = subject_alt_name.value.split(', ').map do |names|
          names.split(':', 2)[1]
        end
        expect(alternative_names).to match_array(['127.0.0.1', '*.my-instance-group.a.simple.bosh'])
      end
    end

    it 'create respective consumer and link object' do
      deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

      consumers = get('/link_consumers', "deployment=#{deployment_name}")
      expect(consumers.count).to eq(1)
      expect(consumers[0]['owner_object']['name']).to eq('bbs')

      links = get('/links', "deployment=#{deployment_name}")
      expect(links.count).to eq(1)
      expect(links[0]['link_consumer_id']).to eq(consumers[0]['id'])

    end

    context 'when provider is updated and we have new link for variable consumer' do
      before do
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)
      end

      it 'should remove old links' do
        deployment_manifest['instance_groups'][0]['jobs'][0]['properties']['b'] = 'barbar'

        old_links = get('/links', "deployment=#{deployment_name}")
        expect(old_links.count).to eq(1)

        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

        new_links = get('/links', "deployment=#{deployment_name}")
        expect(new_links.count).to eq(1)
        expect(new_links[0]['id']).to_not eq(old_links[0]['id'])
      end
    end

    context 'when variable consumer is removed' do
      before do
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)
      end

      it 'should remove old links' do
        links = get('/links', "deployment=#{deployment_name}")
        expect(links.count).to eq(1)
        expect(links[0]['id']).to eq('1')

        runtime_config['variables'] = []
        upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false, env: client_env)
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

        consumers = get('/link_consumers', "deployment=#{deployment_name}")
        expect(consumers.count).to eq(0)

        links = get('/links', "deployment=#{deployment_name}")
        expect(links.count).to eq(0)
      end
    end

    context 'when a variable link is in a bad deploy' do
      before do
        deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)
      end
      it 'can recreate the instances' do
        links = get('/links', "deployment=#{deployment_name}")
        expect(links.count).to eq(1)

        deployment_manifest['instance_groups'][0]['jobs'][0]['properties']['b'] = 'barbar'
        runtime_config['variables'] <<
          {
            'name' => 'mine',
            'type' => 'spaghetti',
          }
        upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false, env: client_env)

        deploy_simple_manifest(
          manifest_hash: deployment_manifest,
          include_credentials: false,
          env: client_env,
          failure_expected: true,
        )

        links = get('/links', "deployment=#{deployment_name}")
        expect(links.count).to eq(2)
        bosh_runner.run('recreate', deployment_name: deployment_name, include_credentials: false, env: client_env)
      end
    end

    context 'when wildcard flag is specied in variable' do
      let(:variables) do
        [
          {
            'name' => 'bbs_ca',
            'type' => 'certificate',
            'options' => { 'is_ca' => true },
          },
          {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => {
              'common_name' => {
                'from' => 'http_endpoint',
                'properties' => { 'wildcard' => true },
              },
              'alternative_name' => {
                'from' => 'http_endpoint',
                'properties' => { 'wildcard' => true },
              },
            },
            'options' => { 'ca' => 'bbs_ca', 'alternative_names' => ['127.0.0.1'] },
          },
        ]
      end
      before do
        runtime_config['variables'] = variables
        upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false, env: client_env)
      end

      shared_examples 'generates the certificate' do
        it 'with the dns record as an alternative name' do
          deploy_simple_manifest(manifest_hash: deployment_manifest, include_credentials: false, env: client_env)

          cert = config_server_helper.get_value(prepend_namespace('bbs'))
          cert = OpenSSL::X509::Certificate.new(cert['certificate'])
          subject_alt_name = cert.extensions.find { |e| e.oid == 'subjectAltName' }
          common_name = cert.subject.to_a.find { |e| e.first == 'CN' }[1]

          alternative_names = subject_alt_name.value.split(', ').map do |names|
            names.split(':', 2)[1]
          end

          expect(common_name).to eq(expected_dns)
          expect(alternative_names).to match_array(['127.0.0.1', expected_dns])
        end
      end

      context 'when short DNS is not specified in deployment' do
        let(:expected_dns) { '*.my-instance-group.a.simple.bosh' }

        it_behaves_like 'generates the certificate'
      end

      context 'when deployment has short DNS feature enabled' do
        let(:expected_dns) { '*.q-g1.bosh' }
        before do
          deployment_manifest['features'] = { 'use_short_dns_addresses' => true }
        end

        it_behaves_like 'generates the certificate'
      end

      context 'when use_link_dns_names is enabled' do
        let(:expected_dns) { '*.q-g2.bosh' }
        before do
          deployment_manifest['features'] = { 'use_link_dns_names' => true }
        end

        it_behaves_like 'generates the certificate'
      end
    end
  end
end
