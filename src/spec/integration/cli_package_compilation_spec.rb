require 'spec_helper'

describe 'cli: package compilation', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'uses compile package cache for previously compiled packages' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    simple_blob_store_path = current_sandbox.blobstore_storage_dir

    release_filename = Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')
      output = bosh_runner.run_in_current_dir('create release --with-tarball')
      parse_release_tarball_path(output)
    end

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)

    target_and_login
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{stemcell_filename}")
    bosh_runner.run("upload release #{release_filename}")
    bosh_runner.run('deploy')
    dir_glob = Dir.glob(File.join(simple_blob_store_path, '**/*'))
    cached_items = dir_glob.detect do |cache_item|
      cache_item =~ /foo-/
    end
    expect(cached_items).to_not be(nil)

    # delete release so that the compiled packages are removed from the local blobstore
    bosh_runner.run('delete deployment simple')
    bosh_runner.run('delete release bosh-release')

    # deploy again
    bosh_runner.run("upload release #{release_filename}")
    bosh_runner.run('deploy')

    event_log = bosh_runner.run('task last --event --raw')
    expect(event_log).to match(/Downloading '.+' from global cache/)
    expect(event_log).to_not match(/Compiling packages/)
  end

  RELEASE_COMPILATION_TEMPLATE_ASSETS = File.join(ASSETS_DIR, 'release_compilation_test_release')
  TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX = File.join(ClientSandbox.base_dir, 'release_compilation_test_release')
  before do
    FileUtils.rm_rf(TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)
    FileUtils.cp_r(RELEASE_COMPILATION_TEMPLATE_ASSETS, TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX, :preserve => true)

    Dir.chdir(TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX) do
      ignore = %w(
        blobs
        dev-releases
        config/dev.yml
        config/private.yml
        releases/*.tgz
        dev_releases
        .dev_builds
        .final_builds/jobs/**/*.tgz
        .final_builds/packages/**/*.tgz
        blobs
        .blobs
        .DS_Store
      )

      File.open('.gitignore', 'w+') do |f|
        f.write(ignore.join("\n") + "\n")
      end

      `git init;
       git config user.name "John Doe";
       git config user.email "john.doe@example.org";
       git add .;
       git commit -m "Initial Test Commit"`
    end

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
    deployment_manifest = yaml_file('whatevs_manifest', manifest_hash)

    target_and_login
    puts bosh_runner.run_in_dir("create release", TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)
    puts bosh_runner.run_in_dir('upload release', TEST_RELEASE_COMPILATION_TEMPLATE_SANDBOX)


    bosh_runner.run("update cloud-config #{cloud_manifest.path}")
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run('deploy')

    foobar_vm = director.vm('foobar', '0')
    apply_spec= current_sandbox.cpi.current_apply_spec_for_vm(foobar_vm.cid)
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
