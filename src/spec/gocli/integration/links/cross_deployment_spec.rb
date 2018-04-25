require 'spec_helper'

describe 'cross deployment links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  def bosh_run_cck_with_resolution_with_name(deployment_name, num_errors, option = 1, env = {})
    env.each do |key, value|
      ENV[key] = value
    end

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

  let(:first_manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['name'] = 'first'
    manifest['instance_groups'] = [first_deployment_instance_group_spec]
    manifest
  end

  let(:first_deployment_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'first_deployment_node',
      jobs: [{ 'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links }],
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
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'second_deployment_node',
      jobs: [{ 'name' => 'node', 'consumes' => second_deployment_consumed_links }],
      instances: 1,
      static_ips: ['192.168.1.11'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:second_manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
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
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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

      context 'and the consumer is recreated via resurrector' do
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
          expect do
            deploy_simple_manifest(manifest_hash: second_manifest)
          end.to raise_error(RuntimeError, /Can't resolve link 'node1' for job 'node' in instance group 'second_deployment_node' in deployment 'second'/)
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
          Regexp.new(
            "Failed to resolve links from deployment 'second'. See errors below:\n" \
            "  - Can't resolve link 'node1' in instance group "\
            "'second_deployment_node' on job 'node' in deployment 'second' with "\
            "network 'invalid-network'",
          ),
        )
      end

      context 'when provider job has 0 instances' do
        let(:first_deployment_instance_group_spec) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'first_deployment_node',
            jobs: [{ 'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links }],
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
            Regexp.new(
              "Failed to resolve links from deployment 'second'. See errors below:\n" \
              "  - Can't resolve link 'node1' in instance group "\
              "'second_deployment_node' on job 'node' in deployment 'second' with "\
              "network 'invalid-network'",
            ),
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

      expect do
        deploy_simple_manifest(manifest_hash: second_manifest)
      end.to raise_error(RuntimeError, /Can't resolve link 'node1' for job 'node' in instance group 'second_deployment_node' in deployment 'second'/)
    end
  end
end
