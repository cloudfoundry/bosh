require 'spec_helper'

describe 'cross deployment links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, IntegrationSupport::ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', IntegrationSupport::ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', IntegrationSupport::ClientSandbox.links_release_dir)
  end

  def bosh_run_cck_with_resolution_with_name(deployment_name, num_errors, option = 1)
    output = ''
    bosh_runner.run_interactively('cck', deployment_name: deployment_name) do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end

  def add_extra_networks_with_single_ip(cloud_config_hash)

    new_network_b = {
      'name' => 'b',
      'subnets' => [{
                      'range' => '10.0.1.0/24',
                      'gateway' => '10.0.1.1',
                      'dns' => ['10.0.1.1'],
                      'static' => ['10.0.1.2'],
                      'reserved' => [],
                      'cloud_properties' => {},
                      'az' => 'z1',
                    }]
    }
    new_network_c = {
      'name' => 'c',
      'subnets' => [{
                      'range' => '10.0.2.0/24',
                      'gateway' => '10.0.2.1',
                      'dns' => ['10.0.2.1'],
                      'static' => ['10.0.2.2'],
                      'reserved' => [],
                      'cloud_properties' => {},
                      'az' => 'z1',
                    }]
    }
    cloud_config['networks'].push(new_network_b)
    cloud_config['networks'].push(new_network_c)
  end

  let(:first_manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['name'] = 'first'
    manifest['instance_groups'] = [first_deployment_instance_group_spec]
    manifest
  end

  let(:first_deployment_instance_group_spec) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'first_deployment_node',
      jobs: [
        {
          'name' => 'node',
          'release' => 'bosh-release',
          'consumes' => first_deployment_consumed_links,
          'provides' => first_deployment_provided_links,
        },
      ],
      instances: 1,
      static_ips: ['192.168.1.10'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:first_deployment_consumed_links) do
    {
      'node1' => { 'from' => 'node1', 'deployment' => 'first' },
      'node2' => { 'from' => 'node2', 'deployment' => 'first' },
    }
  end

  let(:first_deployment_provided_links) do
    { 'node1' => { 'shared' => true },
      'node2' => { 'shared' => true } }
  end

  let(:second_deployment_instance_group_spec) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'second_deployment_node',
      jobs: [{ 'name' => 'node', 'release' => 'bosh-release', 'consumes' => second_deployment_consumed_links }],
      instances: 1,
      static_ips: ['192.168.1.11'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:second_manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['name'] = 'second'
    manifest['instance_groups'] = [second_deployment_instance_group_spec]
    manifest
  end

  let(:second_deployment_consumed_links) do
    {
      'node1' => { 'from' => 'node1', 'deployment' => 'first' },
      'node2' => { 'from' => 'node2', 'deployment' => 'second' },
    }
  end

  let(:cloud_config) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
        'name' => 'dynamic-network',
        'type' => 'dynamic',
        'subnets' => [{'az' => 'z1'}]
    }

    cloud_config_hash
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when consumed link is shared across deployments' do
    it 'should successfully use the shared link' do
      deploy_simple_manifest(manifest_hash: first_manifest)

      expect do
        deploy_simple_manifest(manifest_hash: second_manifest)
      end.to_not raise_error
    end

    it 'allows access to bootstrap node' do
      deploy_simple_manifest(manifest_hash: first_manifest)

      first_deployment_instance = director.instance('first_deployment_node', '0', deployment_name: 'first')
      first_deployment_template = YAML.safe_load(first_deployment_instance.read_job_template('node', 'config.yml'))

      second_manifest['instance_groups'][0]['instances'] = 2
      second_manifest['instance_groups'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']
      second_manifest['instance_groups'][0]['networks'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']

      deploy_simple_manifest(manifest_hash: second_manifest)

      second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
      second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))
      expect(second_deployment_template['instances']['node1_bootstrap_address']).to eq(first_deployment_template['instances']['node1_bootstrap_address'])
    end

    context 'when the provider is updated' do
      before do
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)

        first_manifest['instance_groups'][0]['jobs'][0]['provides']['node1']['shared'] = false
        deploy_simple_manifest(manifest_hash: first_manifest)
      end

      context 'and the consumer is stopped and started' do
        it 'should preserve the old link information' do
          expect { bosh_runner.run('stop --hard', deployment_name: 'second') }.to_not raise_error
          expect { bosh_runner.run('start', deployment_name: 'second') }.to_not raise_error
        end
      end

      context 'and the consumer is recreated via cck' do
        before do
          expect { bosh_runner.run('update-resurrection off') }.to_not raise_error
        end

        after do
          expect { bosh_runner.run('update-resurrection on') }.to_not raise_error
        end

        it 'should preserve the old link information' do
          director.instance('second_deployment_node', '0', deployment_name: 'second').kill_agent

          cck_output = bosh_run_cck_with_resolution_with_name('second', 1, 4)
          expect(cck_output).to match(/Recreate VM and wait for processes to start/)
          expect(cck_output).to match(/Task .* done/)

          expect(bosh_runner.run('cloud-check --report', deployment_name: 'second')).to match(regexp('0 problems'))
        end
      end

      context 'and the consumer is redeployed' do
        it 'should fail to resolve the link' do
          expect { deploy_simple_manifest(manifest_hash: second_manifest) }.to raise_error(
            RuntimeError,
            Regexp.new(<<~OUTPUT.strip))
              Failed to resolve links from deployment 'second'. See errors below:
                - Failed to resolve link 'node1' with type 'node1' from job 'node' in instance group 'second_deployment_node'. Details below:
                  - No link providers found
            OUTPUT
        end
      end
    end

    context 'when the provider fails to deploy' do
      before do
        first_manifest['instance_groups'][0]['azs'] = ['unknown_az']
        _, exit_code = deploy_simple_manifest(manifest_hash: first_manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
      end

      it 'causes the consumer to fail gracefully' do
        second_manifest['instance_groups'][0]['jobs'][0]['consumes']['node1']['network'] = 'a'
        output, exit_code = deploy_simple_manifest(manifest_hash: second_manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include(<<~ERROR.strip)
          Error: Failed to resolve links from deployment 'second'. See errors below:
            - Failed to resolve link 'node1' with type 'node1' from job 'node' in instance group 'second_deployment_node'. Details below:
              - Link provider 'node1' from job 'node' in instance group 'first_deployment_node' in deployment 'first' does not belong to network 'a'
        ERROR
      end
    end

    context 'when network changes to non-static in consumer and provider' do
      before do
        first_manifest['instance_groups'][0]['networks'][0].delete('static_ips')
        second_manifest['instance_groups'][0]['networks'][0].delete('static_ips')
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)
        add_extra_networks_with_single_ip(cloud_config)
        upload_cloud_config(cloud_config_hash: cloud_config)
      end

      context 'when deployments change to a different network' do
        it 'should create a new links which use new network addresses' do
          initial_links_response = send_director_get_request('/links', 'deployment=second')
          initial_links = JSON.parse(initial_links_response.read_body)
          initial_link_addresses = {}

          initial_links.each do |initial_link|
            initial_links_address_response = send_director_get_request('/link_address', "link_id=#{initial_link['id']}&az=z1")
            initial_links_address = JSON.parse(initial_links_address_response.read_body)
            initial_link_addresses[initial_link['name']] = initial_links_address
          end

          first_manifest['instance_groups'][0]['networks'][0]['name'] = 'b'
          deploy_simple_manifest(manifest_hash: first_manifest)

          second_manifest['instance_groups'][0]['networks'][0]['name'] = 'c'
          deploy_simple_manifest(manifest_hash: second_manifest)

          final_links_response = send_director_get_request('/links', 'deployment=second')
          final_links = JSON.parse(final_links_response.read_body)
          final_link_addresses = {}

          final_links.each do |final_link|
            final_links_address_response = send_director_get_request('/link_address', "link_id=#{final_link['id']}&az=z1")
            final_links_address = JSON.parse(final_links_address_response.read_body)
            final_link_addresses[final_link['name']] = final_links_address
          end

          initial_links.each do |initial_link|
            final_link = final_links.select {|final_link| final_link['name'] == initial_link['name']}.first
            expect(final_link).to_not be_nil
            expect(final_link['id']).to_not eq(initial_link['id'])

            expect(initial_link_addresses[initial_link['name']]['address']).to_not eq(final_link_addresses[final_link['name']]['address'])
          end
        end
      end
    end

    context 'when user does not specify a network for consumes' do
      it 'should use default network' do
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)

        second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
        second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['instances']['node1_ips']).to eq(['192.168.1.10'])
        expect(second_deployment_template['instances']['node2_ips']).to eq(['192.168.1.11'])
      end
    end

    context 'when user specifies a valid network for consumes' do
      let(:second_deployment_consumed_links) do
        {
          'node1' => { 'from' => 'node1', 'deployment' => 'first', 'network' => 'test' },
          'node2' => { 'from' => 'node2', 'deployment' => 'second' },
        }
      end

      before do
        cloud_config['networks'] << {
          'name' => 'test',
          'type' => 'dynamic',
          'subnets' => [{ 'az' => 'z1' }],
        }

        first_deployment_instance_group_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => %w[dns gateway],
        }

        first_deployment_instance_group_spec['networks'] << {
          'name' => 'test',
        }

        upload_cloud_config(cloud_config_hash: cloud_config)
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)
      end

      it 'should use user specified network from provider job' do
        second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
        second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['instances']['node1_ips'].first).to match(/.test./)
        expect(second_deployment_template['instances']['node2_ips'].first).to eq('192.168.1.11')
      end

      it 'uses the user specified network for link address FQDN' do
        second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
        second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['node1_dns']).to eq('q-s0.first-deployment-node.test.first.bosh')
      end
    end

    context 'when user specifies an invalid network for consumes' do
      let(:second_deployment_consumed_links) do
        {
          'node1' => { 'from' => 'node1', 'deployment' => 'first', 'network' => 'invalid-network' },
          'node2' => { 'from' => 'node2', 'deployment' => 'second' },
        }
      end

      it 'raises an error' do
        deploy_simple_manifest(manifest_hash: first_manifest)

        expect do
          deploy_simple_manifest(manifest_hash: second_manifest)
        end.to raise_error(
          RuntimeError,
          Regexp.new(<<~ERROR
            Failed to resolve links from deployment 'second'. See errors below:
              - Failed to resolve link 'node1' with type 'node1' from job 'node' in instance group 'second_deployment_node'. Details below:
                - Link provider 'node1' from job 'node' in instance group 'first_deployment_node' in deployment 'first' does not belong to network 'invalid-network'
          ERROR
          .strip),
        )
      end

      context 'when provider job has 0 instances' do
        let(:first_deployment_instance_group_spec) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'first_deployment_node',
            jobs: [
              {
                'name' => 'node',
                'release' => 'bosh-release',
                'consumes' => first_deployment_consumed_links,
                'provides' => first_deployment_provided_links,
              },
            ],
            instances: 0,
            static_ips: [],
          )
          spec['azs'] = ['z1']
          spec
        end

        it 'raises the error' do
          deploy_simple_manifest(manifest_hash: first_manifest)

          expect do
            deploy_simple_manifest(manifest_hash: second_manifest)
          end.to raise_error(
            RuntimeError,
            Regexp.new(<<~ERROR
              Failed to resolve links from deployment 'second'. See errors below:
                - Failed to resolve link 'node1' with type 'node1' from job 'node' in instance group 'second_deployment_node'. Details below:
                  - Link provider 'node1' from job 'node' in instance group 'first_deployment_node' in deployment 'first' does not belong to network 'invalid-network'
            ERROR
            .strip),
          )
        end
      end
    end
  end

  context 'when consumed link is not shared across deployments' do
    let(:first_deployment_provided_links) do
      { 'node1' => { 'shared' => false } }
    end

    it 'should raise an error' do
      deploy_simple_manifest(manifest_hash: first_manifest)

      expect { deploy_simple_manifest(manifest_hash: second_manifest) }.to raise_error do |error|
        expect(error.message).to include(<<~OUTPUT.strip)
          Error: Failed to resolve links from deployment 'second'. See errors below:
            - Failed to resolve link 'node1' with type 'node1' from job 'node' in instance group 'second_deployment_node'. Details below:
              - No link providers found
        OUTPUT
      end
    end
  end

  describe 'when director local_dns is enabled' do
    with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false, 'use_dns_addresses' => true})

    before do
      upload_links_release
      upload_stemcell

      add_extra_networks_with_single_ip(cloud_config)
      upload_cloud_config(cloud_config_hash: cloud_config) 
      first_manifest
    end

    context 'when link is provided and consumed (cross-deployment) and provider has default DNS enabled' do
      before do
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)
      end

      it 'should create link with DNS' do
        second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
        second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['instances']['node1_ips'][0]).to match(/.first-deployment-node.a.first.bosh/)
        expect(second_deployment_template['instances']['node2_ips'][0]).to match(/.second-deployment-node.a.second.bosh/)
      end
    end

    context 'when provider use_dns_address is not specified (default get director behaviour)' do
      context 'when consumer specifies use_dns_address as FALSE' do
        let(:features_hash) do
          { 'use_dns_addresses' => false }
        end
        before do
          deploy_simple_manifest(manifest_hash: first_manifest)
          second_manifest['features'] = features_hash
          deploy_simple_manifest(manifest_hash: second_manifest)
        end

        it 'should create link with DNS only for cross-deployment' do
          second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
          second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

          expect(second_deployment_template['instances']['node1_ips'][0]).to match(/.first-deployment-node.a.first.bosh/)
          expect(second_deployment_template['instances']['node2_ips']).to eq(['192.168.1.11'])
        end
      end

      context 'when consumer specifies use_dns_address as TRUE' do
        let(:features_hash) do
          { 'use_dns_addresses' => true }
        end
        before do
          deploy_simple_manifest(manifest_hash: first_manifest)
          second_manifest['features'] = features_hash
          deploy_simple_manifest(manifest_hash: second_manifest)
        end

        it 'should create link with DNS address for all links' do
          second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
          second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

          expect(second_deployment_template['instances']['node1_ips'][0]).to match(/.first-deployment-node.a.first.bosh/)
          expect(second_deployment_template['instances']['node2_ips'][0]).to match(/.second-deployment-node.a.second.bosh/)
        end

        context 'when consumer explicitly request for ip_address' do
          let(:second_deployment_consumed_links) do
            {
              'node1' => { 'from' => 'node1', 'deployment' => 'first', 'ip_addresses' => true },
              'node2' => { 'from' => 'node2', 'deployment' => 'second' },
            }
          end

          it 'should create link with IP for cross-deployment link and DNS for implicit link' do
            second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
            second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

            expect(second_deployment_template['instances']['node1_ips']).to eq(['192.168.1.10'])
            expect(second_deployment_template['instances']['node2_ips'][0]).to match(/.second-deployment-node.a.second.bosh/)
          end
        end

      end
    end

    context 'when provider use_dns_address is FALSE' do
      let(:features_hash) do
        { 'use_dns_addresses' => false }
      end

      before do
        first_manifest['features'] = features_hash
        deploy_simple_manifest(manifest_hash: first_manifest)

        deploy_output = deploy_simple_manifest(manifest_hash: second_manifest)
        task_id = IntegrationSupport::OutputParser.new(deploy_output).task_id
        @task_debug_logs = bosh_runner.run("task --debug #{task_id}")
      end

      it 'should create link with IP' do
        second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
        second_deployment_template = YAML.safe_load(second_deployment_instance.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['instances']['node1_ips']).to eq(['192.168.1.10'])
        expect(second_deployment_template['instances']['node2_ips'][0]).to match(/.second-deployment-node.a.second.bosh/)
        expect(@task_debug_logs).to match("DirectorJobRunner: DNS address not available for the link provider instance: first_deployment_node")
      end
    end
  end
end
