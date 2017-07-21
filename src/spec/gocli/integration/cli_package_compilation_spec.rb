require_relative '../spec_helper'

describe 'cli: package compilation', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  let!(:release_file) { Tempfile.new('release.tgz') }
  after { release_file.delete }

  def uses_compile_package_cache_for_previously_compiled_packages(foo_sha, bar_sha)
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    simple_blob_store_path = current_sandbox.blobstore_storage_dir

    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')
      bosh_runner.run_in_current_dir("create-release --tarball=#{release_file.path}")
    end

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)

    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
    bosh_runner.run("upload-release #{release_file.path}")

    output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
    expect(output).to match /Compiling packages: foo\/#{foo_sha}/
    expect(output).to match /Compiling packages: bar\/#{bar_sha}/

    bosh_runner.run("instances", deployment_name: 'simple')
    bosh_runner.run("vms", deployment_name: 'simple')

    dir_glob = Dir.glob(File.join(simple_blob_store_path, '**/*'))
    cached_items = dir_glob.detect do |cache_item|
      cache_item =~ /foo-/
    end
    expect(cached_items).to_not be(nil)

    bosh_runner.run('delete-deployment', deployment_name: 'simple')
    bosh_runner.run('delete-release bosh-release')

    bosh_runner.run("upload-release #{release_file.path}")
    output =  bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')

    expect(output).to match /Preparing package compilation: Downloading 'foo\/#{foo_sha}' from global cache/
    expect(output).to_not match /Compiling packages: foo\/#{foo_sha}/
    expect(output).to_not match /Compiling packages: bar\/#{bar_sha}/
  end

  it 'uses compile package cache for previously compiled packages in sha1 mode', sha1: true do
    uses_compile_package_cache_for_previously_compiled_packages('0ee95716c58cf7aab3ef7301ff907118552c2dda', 'f1267e1d4e06b60c91ef648fb9242e33ddcffa73')
  end

  it 'uses compile package cache for previously compiled packages in sha2 mode', sha2: true do
    uses_compile_package_cache_for_previously_compiled_packages('a915ffa8d7a3761a31dc613f1f39e1d80e03db07d173bb28ecf2e8d690cf5b20', '637044d11958dea0a9ce300dd4e24c2f5609d653fbcd7a3afb6c3adc82b39939')
  end

  RELEASE_COMPILATION_TEMPLATE_ASSETS = File.join(ASSETS_DIR, 'release_compilation_test_release')
  TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX = File.join(ClientSandbox.base_dir, 'release_compilation_test_release')
  before do
    FileUtils.rm_rf(TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)
    FileUtils.cp_r(RELEASE_COMPILATION_TEMPLATE_ASSETS, TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX, :preserve => true)
  end

  # This should be a unit test. Need to figure out best placement.
  it "includes only immediate dependencies of the job's templates in the apply_spec" do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'][0]['size'] = 1

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['templates'] = [{'name' => 'foobar'}, {'name' => 'goobaz'}]
    manifest_hash['jobs'][0]['instances'] = 1

    manifest_hash['releases'].first['name'] = 'release_compilation_test'
    manifest_hash['releases'].first['version'] = 'latest'

    cloud_manifest = yaml_file('cloud_manifest', cloud_config_hash)

    bosh_runner.run_in_dir('create-release --force', TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)
    bosh_runner.run_in_dir('upload-release', TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)

    bosh_runner.run("update-cloud-config #{cloud_manifest.path}")
    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
    deploy_simple_manifest(manifest_hash: manifest_hash)

    foobar_instance = director.instance('foobar', '0')
    apply_spec= current_sandbox.cpi.current_apply_spec_for_vm(foobar_instance.vm_cid)
    packages = apply_spec['packages']

    expect(packages.keys).to match_array(%w(foo bar baz))
  end

  it 'returns truncated output' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['templates'].first['name'] = 'fails_with_too_much_output'
    manifest_hash['jobs'][0]['instances'] = 1
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['compilation']['workers'] = 1

    deploy_output = deploy_from_scratch(
      cloud_config_hash: cloud_config_hash,
      manifest_hash: manifest_hash,
      failure_expected: true
    )

    expect(deploy_output).to include('Truncated stdout: bbbbbbbbbb')
    expect(deploy_output).to include('Truncated stderr: yyyyyyyyyy')
    expect(deploy_output).to_not include('aaaaaaaaa')
    expect(deploy_output).to_not include('nnnnnnnnn')
  end

  context 'when there is no available IPs for compilation' do
    it 'fails deploy' do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

      subnet_without_dynamic_ips_available =  {
        'range' => '192.168.1.0/30',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1'],
        'static' => ['192.168.1.2'],
        'reserved' => [],
        'cloud_properties' => {},
      }

      cloud_config_hash['networks'].first['subnets'] = [subnet_without_dynamic_ips_available]
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(instances: 1, static_ips: ['192.168.1.2'])]

      deploy_output = deploy_from_scratch(
        cloud_config_hash: cloud_config_hash,
        manifest_hash: manifest_hash,
        failure_expected: true
      )

      expect(deploy_output).to match(
        /Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/
      )

      expect(director.vms.size).to eq(0)
    end
  end
end
