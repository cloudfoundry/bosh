require 'spec_helper'

describe 'deploy job with addons', type: :integration do
  with_reset_sandbox_before_each

  it 'allows addons to be added to specific deployments' do
    target_and_login

    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon_includes)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell
    upload_cloud_config

    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    # deploy Deployment1
    manifest_hash['name'] = 'dep1'
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar', '0', deployment: 'dep1')

    expect(File.exist?(foobar_vm.job_path('dummy_with_properties'))).to eq(true)
    template = foobar_vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'prop_value'")

    # deploy Deployement2
    manifest_hash['name'] = 'dep2'
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar', '0', deployment: 'dep2')

    expect(File.exist?(foobar_vm.job_path('dummy_with_properties'))).to eq(false)

    expect(File.exist?(foobar_vm.job_path('foobar'))).to eq(true)
  end

  it 'allows addons to be added for specific stemcell operating systems' do
    target_and_login

    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon_includes_stemcell_os)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell   # name: ubuntu-stemcell, os: toronto-os
    upload_stemcell_2 # name: centos-stemcell, os: toronto-centos

    manifest_hash = Bosh::Spec::Deployments.stemcell_os_specific_addon_manifest

    cloud_config_hash = Bosh::Spec::Deployments.simple_os_specific_cloud_config
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    deploy_simple_manifest(manifest_hash: manifest_hash)

    vms = director.vms

    addon_vm = vms.detect { |vm| vm.job_name == "has-addon-vm" }
    expect(File.exist?(addon_vm.job_path('foobar'))).to eq(true)
    expect(File.exist?(addon_vm.job_path('dummy'))).to eq(true)

    no_addon_vm = vms.detect { |vm| vm.job_name == "no-addon-vm" }
    expect(File.exist?(no_addon_vm.job_path('foobar'))).to eq(true)
    expect(File.exist?(no_addon_vm.job_path('dummy'))).to eq(false)
  end

  it 'collocates addon jobs with deployment jobs and evaluates addon properties' do
    target_and_login

    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    upload_cloud_config(manifest_hash: manifest_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar', '0')

    expect(File.exist?(foobar_vm.job_path('dummy_with_properties'))).to eq(true)
    expect(File.exist?(foobar_vm.job_path('foobar'))).to eq(true)

    template = foobar_vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'addon_prop_value'")
  end

  it 'raises an error if the addon job has the same name as an existing job in an instance group' do
    target_and_login

    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    upload_cloud_config(manifest_hash: manifest_hash)

    manifest_hash['releases'] = [{'name' => 'bosh-release', 'version' => '0.1-dev'}, {'name' => 'dummy2', 'version' => '0.2-dev'}]
    manifest_hash['jobs'][0]['templates'] = [{'name' => 'dummy_with_properties', "release" => "dummy2"}]

    expect{deploy_simple_manifest({manifest_hash: manifest_hash})}.to raise_error(RuntimeError, /Colocated job 'dummy_with_properties' is already added to the instance group 'foobar'/)
  end

  it 'ensures that addon job properties are assigned' do
    target_and_login

    runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.runtime_config_with_addon)
    runtime_config['addons'][0]['jobs'][0]['properties'] = {'dummy_with_properties' => {'echo_value' => 'new_prop_value'}}

    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    upload_cloud_config(manifest_hash: manifest_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar', '0')

    expect(File.exist?(foobar_vm.job_path('dummy_with_properties'))).to eq(true)
    expect(File.exist?(foobar_vm.job_path('foobar'))).to eq(true)

    template = foobar_vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'new_prop_value'")
  end

  it 'succeeds when deployment and runtime config both have the same release with the same version' do
    target_and_login

    runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.simple_runtime_config)
    expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

    bosh_runner.run("upload release #{spec_asset('test_release.tgz')}")
    bosh_runner.run("upload release #{spec_asset('test_release_2.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.multiple_release_manifest
    upload_cloud_config(manifest_hash: manifest_hash)
    deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)

    # ensure that the diff only contains one instance of the release
    expect(deploy_output.scan(/test_release_2/).count).to eq(1)
  end

  context 'when version of uploaded release is same as one used in addon and one is an integer' do
    it 'deploys it after comparing both versions as a string' do
      target_and_login

      bosh_runner.run("upload release #{spec_asset('test_release_2.tgz')}")

      runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)
      runtime_config['releases'][0]['version'] = 2
      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update runtime-config #{runtime_config_file.path}")).to include("Successfully updated runtime config")

      upload_stemcell

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'] = [{'name'    => 'test_release_2',
                                      'version' => '2'}]
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(
        name: 'job',
        templates: [{'name' => 'job_using_pkg_1'}],
        instances: 1,
        static_ips: ['192.168.1.10']
      )]

      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end
  end
end
