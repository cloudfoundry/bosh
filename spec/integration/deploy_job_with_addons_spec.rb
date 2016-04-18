require 'spec_helper'

describe 'deploy job with addons', type: :integration do
  with_reset_sandbox_before_each

  it 'collocates addon jobs with deployment jobs and evaluates addon properties' do
    target_and_login

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_with_addon))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}")).to include("Successfully updated runtime config")
    end

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
    expect(template).to include("echo 'prop_value'")
  end

  it 'succeeds when deployment and runtime config both have the same release with the same version' do
    target_and_login

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_runtime_config))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}")).to include("Successfully updated runtime config")
    end

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

      Dir.mktmpdir do |tmpdir|
        runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
        runtime_config = Bosh::Spec::Deployments.simple_runtime_config
        runtime_config['releases'][0]['version'] = 2
        File.write(runtime_config_filename, Psych.dump(runtime_config))
        expect(bosh_runner.run("update runtime-config #{runtime_config_filename}")).to include("Successfully updated runtime config")
      end

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
