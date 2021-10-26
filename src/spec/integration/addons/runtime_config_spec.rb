require 'spec_helper'

describe 'runtime config', type: :integration do
  with_reset_sandbox_before_each

  it 'collocates addon jobs with deployment jobs and evaluates addon properties' do
    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
    expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

    bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups

    upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_instance = director.instance('foobar', '0')

    expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
    expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

    template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'addon_prop_value'")
  end

  it 'raises an error if the addon job has the same name as an existing job in an instance group' do
    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
    expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

    bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

    manifest_hash['releases'] = [
      { 'name' => 'bosh-release', 'version' => '0.1-dev' },
      { 'name' => 'dummy2', 'version' => '0.2-dev' },
    ]
    manifest_hash['instance_groups'][0]['jobs'] = [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }]

    expect do
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end.to raise_error(
      RuntimeError,
      /Colocated job 'dummy_with_properties' is already added to the instance group 'foobar'/,
    )
  end

  it 'ensures that addon job properties are assigned' do
    runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.runtime_config_with_addon)
    runtime_config['addons'][0]['jobs'][0]['properties'] = { 'dummy_with_properties' => { 'echo_value' => 'new_prop_value' } }
    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
    expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

    bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_instance = director.instance('foobar', '0')

    expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
    expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

    template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'new_prop_value'")
  end

  it 'succeeds when deployment and runtime config both have the same release with the same version' do
    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.simple_runtime_config)
    expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

    bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
    bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.multiple_release_manifest
    upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
    deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)

    # ensure that the diff only contains one instance of the release
    expect(deploy_output.scan(/test_release_2/).count).to eq(1)
  end

  context 'when version of uploaded release is same as one used in addon and one is an integer' do
    it 'deploys it after comparing both versions as a string' do
      bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")

      runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config('test_release_2', 2, 'job_using_pkg_1'))
      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      upload_stemcell

      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['releases'] = [{ 'name' => 'test_release_2',
                                     'version' => '2' }]

      manifest_hash['instance_groups'] = [Bosh::Spec::Deployments.simple_instance_group(
        name: 'instance_group',
        jobs: [{ 'name' => 'job_using_pkg_1', 'release' => 'test_release_2' }],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )]

      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end
  end

  context 'when availability zones are specified' do
    it 'allows addons to be added to the runtime config' do
      runtime_config = Bosh::Spec::Deployments.runtime_config_with_addon
      runtime_config['addons'][0]['include'] = { 'azs' => ['z1'] }
      runtime_config['addons'][0]['exclude'] = { 'azs' => ['z2'] }
      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)

      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups

      manifest_hash['name'] = 'dep1'
      manifest_hash['instance_groups'].first['azs'] = ['z1']
      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs,
      )
      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'addon_prop_value'")

      manifest_hash['name'] = 'dep2'
      manifest_hash['instance_groups'].first['azs'] = ['z2']
      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs,
      )
      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
    end

    it 'allows addons to be added to the deployment manifest' do
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.manifest_with_addons
      manifest_hash['addons'][0]['include'] = { 'azs' => ['z1'] }
      manifest_hash['addons'][0]['exclude'] = { 'azs' => ['z2'] }

      manifest_hash['name'] = 'dep1'
      manifest_hash['instance_groups'].first['azs'] = ['z1']

      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs,
      )
      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      manifest_hash['name'] = 'dep2'
      manifest_hash['instance_groups'].first['azs'] = ['z2']
      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs,
      )
      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
    end
  end

  context 'runtime config entries are excluded from current deployment' do
    let(:manifest_hash) do
      Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    end

    let(:runtime_config) do
      Bosh::Spec::Deployments.runtime_config_with_addon.tap do |config|
        config['addons'][0].merge!(addon_exclude)
      end
    end

    let(:addon_exclude) do
      {
        'exclude' => {
          'deployments' => ['simple'],
        },
      }
    end

    before do
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")
    end

    it 'should not associate unused release with the current deployment' do
      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
        runtime_config_hash: runtime_config,
      )

      expect(bosh_runner.run('-d simple deployment')).to_not include('dummy2')
    end
  end
end
