require 'spec_helper'

describe 'cli: package compilation', type: :integration do
  include IntegrationSupport::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  let(:test_release_compilation_template_sandbox) { File.join(IntegrationSupport::Sandbox.sandbox_client_dir, 'release_compilation_test_release') }

  before do
    FileUtils.rm_rf(test_release_compilation_template_sandbox)
    FileUtils.cp_r(File.join(SPEC_ASSETS_DIR, 'release_compilation_test_release'), test_release_compilation_template_sandbox, preserve: true)
  end

  # This should be a unit test. Need to figure out best placement.
  it "includes only immediate dependencies of the instance groups's jobs in the apply_spec" do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config

    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['jobs'] = [
      {
        'name' => 'foobar',
        'release' => 'release_compilation_test',
      },
      {
        'name' => 'goobaz',
        'release' => 'release_compilation_test',
      },
    ]
    manifest_hash['instance_groups'].first['instances'] = 1

    manifest_hash['releases'].first['name'] = 'release_compilation_test'
    manifest_hash['releases'].first['version'] = 'latest'

    cloud_manifest = yaml_file('cloud_manifest', cloud_config_hash)

    bosh_runner.run_in_dir('create-release --force', test_release_compilation_template_sandbox)
    bosh_runner.run_in_dir('upload-release', test_release_compilation_template_sandbox)

    bosh_runner.run("update-cloud-config #{cloud_manifest.path}")
    bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_instance = director.instance('foobar', '0')
    apply_spec = current_sandbox.cpi.current_apply_spec_for_vm(foobar_instance.vm_cid)
    packages = apply_spec['packages']

    expect(packages.keys).to match_array(%w[foo bar baz])
  end

  it 'returns truncated output' do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['jobs'].first['name'] = 'fails_with_too_much_output'
    manifest_hash['instance_groups'].first['instances'] = 1
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['compilation']['workers'] = 1

    deploy_output = deploy_from_scratch(
      cloud_config_hash: cloud_config_hash,
      manifest_hash: manifest_hash,
      failure_expected: true,
    )

    expect(deploy_output).to include('Truncated stdout: bbbbbbbbbb')
    expect(deploy_output).to include('Truncated stderr: yyyyyyyyyy')
    expect(deploy_output).to_not include('aaaaaaaaa')
    expect(deploy_output).to_not include('nnnnnnnnn')
  end

  context 'when there is no available IPs for compilation' do
    it 'fails deploy' do
      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      subnet_without_dynamic_ips_available = {
        'range' => '192.168.1.0/30',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1'],
        'static' => ['192.168.1.2'],
        'reserved' => [],
        'cloud_properties' => {},
      }

      cloud_config_hash['networks'].first['subnets'] = [subnet_without_dynamic_ips_available]
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(instances: 1, static_ips: ['192.168.1.2']),
      ]

      deploy_output = deploy_from_scratch(
        cloud_config_hash: cloud_config_hash,
        manifest_hash: manifest_hash,
        failure_expected: true,
      )

      expect(deploy_output).to match(
        /Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/,
      )

      expect(director.vms.size).to eq(0)
    end
  end
end
