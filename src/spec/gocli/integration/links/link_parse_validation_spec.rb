require 'spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when consumer is specified in the manifest but not in the release' do
    let(:instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_instance_group',
        jobs: [
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'consumes' => {
              'link_that_does_not_exist' => {},
            },
          },
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    it 'should warn the about the rogue consumer' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group]

      deploy_output = deploy_simple_manifest(manifest_hash: manifest)
      task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
      task_debug_logs = bosh_runner.run("task --debug #{task_id}")

      expect(task_debug_logs).to include(<<~OUTPUT.strip)
        Manifest defines unknown consumers:
          - Job 'api_server_with_optional_db_link' does not define link consumer 'link_that_does_not_exist' in the release spec
      OUTPUT
    end
  end

  context 'when consumer is specified in the manifest but release does not define any consumers' do
    let(:instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_instance_group',
        jobs: [
          {
            'name' => 'provider',
            'release' => 'bosh-release',
            'consumes' => {
              'link_that_does_not_exist' => {},
            },
          },
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    it 'should warn the about the rogue consumer' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group]

      deploy_output = deploy_simple_manifest(manifest_hash: manifest)
      task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
      task_debug_logs = bosh_runner.run("task --debug #{task_id}")

      expect(task_debug_logs).to include(<<~OUTPUT.strip)
        Manifest defines unknown consumers:
          - Job 'provider' does not define link consumer 'link_that_does_not_exist' in the release spec
      OUTPUT
    end
  end

  context 'when provider is specified in the manifest but not in the release' do
    let(:instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_instance_group',
        jobs: [
          {
            'name' => 'provider',
            'release' => 'bosh-release',
            'provides' => {
              'link_that_does_not_exist' => {},
            },
          },
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    it 'should warn the about the rogue provider' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group]

      deploy_output = deploy_simple_manifest(manifest_hash: manifest)
      task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
      task_debug_logs = bosh_runner.run("task --debug #{task_id}")

      expect(task_debug_logs).to include(<<~OUTPUT.strip)
        Manifest defines unknown providers:
          - Job 'provider' does not define link provider 'link_that_does_not_exist' in the release spec
      OUTPUT
    end
  end

  context 'when provider is specified in the manifest but release does not define any providers' do
    let(:instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_instance_group',
        jobs: [
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'provides' => {
              'link_that_does_not_exist' => {},
            },
          },
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    it 'should warn the about the rogue provider' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group]

      deploy_output = deploy_simple_manifest(manifest_hash: manifest)
      task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id
      task_debug_logs = bosh_runner.run("task --debug #{task_id}")

      expect(task_debug_logs).to include(<<~OUTPUT.strip)
        Manifest defines unknown providers:
          - Job 'api_server_with_optional_db_link' does not define link provider 'link_that_does_not_exist' in the release spec
      OUTPUT
    end
  end
end
