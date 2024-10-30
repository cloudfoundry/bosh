require 'spec_helper'

describe 'basic functionality', type: :integration do
  with_reset_sandbox_before_each

  context 'in runtime configs' do
    it 'allows addons to be added to specific jobs' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_includes
      runtime_config['addons'][0]['include'] = { 'jobs' => [
        { 'name' => 'foobar', 'release' => 'bosh-release' },
      ] }
      runtime_config['addons'][0]['exclude'] = {}

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar_without_packages',
        job_name: 'foobar_without_packages',
      )

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      foobar_instance = director.instance('foobar_without_packages', '0', deployment_name: 'dep1')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
    end

    it 'allows addons to be excluded from specific jobs' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_excludes
      runtime_config['addons'][0]['exclude'] = { 'jobs' => [
        { 'name' => 'foobar_without_packages', 'release' => 'bosh-release' },
      ] }
      runtime_config['addons'][0]['include'] = {}

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar_without_packages',
        job_name: 'foobar_without_packages',
      )

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      foobar_instance = director.instance('foobar_without_packages', '0', deployment_name: 'dep1')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
    end

    it 'allows addons to be added to and excluded from specific deployments' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_includes
      runtime_config['addons'][0]['include'] = { 'jobs' => [
        { 'name' => 'foobar', 'release' => 'bosh-release' },
      ] }
      runtime_config['addons'][0]['exclude'] = { 'deployments' => ['dep2'] }

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      # deploy Deployment2
      manifest_hash['name'] = 'dep2'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)

      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
    end

    it 'allows addons to be added to specific instance groups' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_includes
      runtime_config['addons'][0]['include'] = {
        'instance_groups' => ['ig-1'],
      }
      runtime_config['addons'][0]['exclude'] = {}

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] = []
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'ig-1')
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'ig-2')

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'

      deploy_simple_manifest(manifest_hash: manifest_hash)

      instance1 = director.instance('ig-1', '0', deployment_name: 'dep1')
      instance2 = director.instance('ig-2', '0', deployment_name: 'dep1')

      expect(File.exist?(instance1.job_path('dummy_with_properties'))).to eq(true)
      template = instance1.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      expect(File.exist?(instance2.job_path('dummy_with_properties'))).to eq(false)
    end

    it 'allows addons to be excluded from specific instance groups' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_excludes
      runtime_config['addons'][0]['include'] = {}
      runtime_config['addons'][0]['exclude'] = {
        'instance_groups' => ['ig-2'],
      }

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'ig-1')
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'ig-2')

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      instance1 = director.instance('ig-1', '0', deployment_name: 'dep1')
      instance2 = director.instance('ig-2', '0', deployment_name: 'dep1')

      expect(File.exist?(instance1.job_path('dummy_with_properties'))).to eq(true)
      template = instance1.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      expect(File.exist?(instance2.job_path('dummy_with_properties'))).to eq(false)
    end

    it 'allows addons to be added for specific stemcell operating systems' do
      runtime_config_file = yaml_file(
        'runtime_config.yml',
        SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_includes_stemcell_os,
      )
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell # name: ubuntu-stemcell, os: toronto-os
      upload_stemcell_2 # name: centos-stemcell, os: toronto-centos

      manifest_hash = SharedSupport::DeploymentManifestHelper.stemcell_os_specific_addon_manifest
      manifest_hash['stemcells'] = [
        {
          'alias' => 'toronto',
          'os' => 'toronto-os',
          'version' => 'latest',
        },
        {
          'alias' => 'centos',
          'os' => 'toronto-centos',
          'version' => 'latest',
        },
      ]

      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config_hash['vm_types'] = [
        { 'name' => 'a', 'cloud_properties' => {} },
        { 'name' => 'b', 'cloud_properties' => {} },
      ]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      addon_instance = instances.detect { |instance| instance.instance_group_name == 'has-addon-vm' }
      expect(File.exist?(addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)

      no_addon_instance = instances.detect { |instance| instance.instance_group_name == 'no-addon-vm' }
      expect(File.exist?(no_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)
    end

    it 'allows addons to be added for specific networks' do
      runtime_config_file = yaml_file('runtime_config.yml', SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_includes_network)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell

      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config_hash['networks'] = [
        { 'name' => 'a', 'subnets' => [SharedSupport::DeploymentManifestHelper.subnet] },
        { 'name' => 'b', 'subnets' => [SharedSupport::DeploymentManifestHelper.subnet] },
      ]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = SharedSupport::DeploymentManifestHelper.test_release_manifest_with_stemcell
      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(network_name: 'a', name: 'has-addon-vm', instances: 1),
        SharedSupport::DeploymentManifestHelper.simple_instance_group(network_name: 'b', name: 'no-addon-vm', instances: 1),
      ]
      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      addon_instance = instances.detect { |instance| instance.instance_group_name == 'has-addon-vm' }
      expect(File.exist?(addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)

      no_addon_instance = instances.detect { |instance| instance.instance_group_name == 'no-addon-vm' }
      expect(File.exist?(no_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)
    end

    it 'allows addons to be excluded for specific lifecycle type' do
      runtime_config_file = yaml_file('runtime_config.yml', SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_excludes_lifecycle)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'][1] = SharedSupport::DeploymentManifestHelper.simple_errand_instance_group.merge(
        'name' => 'errand',
      )

      prepare_for_deploy
      deploy_simple_manifest(manifest_hash: manifest_hash)

      bosh_runner.run('run-errand -d simple  errand --keep-alive')
      instances = director.instances

      no_addon_instance = instances.detect { |instance| instance.instance_group_name == 'errand' }
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)

      addon_instance = instances.detect { |instance| instance.instance_group_name == 'foobar' }
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)
    end
  end

  context 'in deployent manifests' do
    it 'allows addon to be added and ensures that addon job properties are properly assigned' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.manifest_with_addons

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")
    end

    it 'allows to apply exclude rules' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.manifest_with_addons
      manifest_hash['addons'][0]['exclude'] = { 'jobs' => [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }] }
      manifest_hash['instance_groups'][1] = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar_without_packages',
        jobs: [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }],
        instances: 1,
      )

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell

      upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      foobar_without_packages_instance = director.instance('foobar_without_packages', '0')
      expect(File.exist?(foobar_without_packages_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(foobar_without_packages_instance.job_path('foobar_without_packages'))).to eq(true)
    end
  end

  context 'in both deployment manifest and runtime config' do
    it 'applies rules from both deployment manifest and from runtime config' do
      runtime_config = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
      runtime_config['addons'][0]['include'] = { 'jobs' => [
        { 'name' => 'foobar', 'release' => 'bosh-release' },
      ] }

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      manifest_hash = SharedSupport::DeploymentManifestHelper.complex_manifest_with_addon

      bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")

      upload_stemcell # name: ubuntu-stemcell, os: toronto-os
      upload_stemcell_2 # name: centos-stemcell, os: toronto-centos

      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_os_specific_cloud_config
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      rc_addon_instance = instances.detect { |instance| instance.instance_group_name == 'has-rc-addon-vm' }
      depl_rc_addons_instance = instances.detect { |instance| instance.instance_group_name == 'has-depl-rc-addons-vm' }
      depl_addon_instance = instances.detect { |instance| instance.instance_group_name == 'has-depl-addon-vm' }

      expect(File.exist?(rc_addon_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(rc_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(rc_addon_instance.job_path('dummy'))).to eq(false)

      expect(File.exist?(depl_rc_addons_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(depl_rc_addons_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(depl_rc_addons_instance.job_path('dummy'))).to eq(true)

      expect(File.exist?(depl_addon_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(depl_addon_instance.job_path('foobar_without_packages'))).to eq(true)
      expect(File.exist?(depl_addon_instance.job_path('dummy'))).to eq(true)
    end
  end

  context 'when a runtime config changes the job ordering' do
    let(:runtime_config) do
      {
        'releases' => [
          { 'name' => 'bosh-release', 'version' => '0.1-dev' },
        ],
        'addons' => [
          { 'name' => 'addon1', 'jobs' => [{ 'name' => 'bazquux', 'release' => 'bosh-release' }] },
          { 'name' => 'addon2', 'jobs' => [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }] },
        ],
      }
    end

    before do
      prepare_for_deploy(runtime_config_hash: runtime_config)
    end

    it 'does not cause updates if job ordering within instance group changes' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      deploy_simple_manifest(manifest_hash: manifest_hash)

      runtime_config['addons'] = [
        { 'name' => 'addon2', 'jobs' => [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }] },
        { 'name' => 'addon1', 'jobs' => [{ 'name' => 'bazquux', 'release' => 'bosh-release' }] },
      ]

      bosh_runner.run("update-runtime-config #{yaml_file('runtime-config', runtime_config).path}")

      output = deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(output).to_not include('Updating')
    end
  end
end
