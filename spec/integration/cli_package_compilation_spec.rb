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

  it 'sends only immediate dependancies to the agent for each package compilation task' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'][0]['size'] = 1

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['template'] = ['foobar', 'goobaz']
    manifest_hash['jobs'][0]['instances'] = 1

    manifest_hash['releases'].first['name'] = 'compilation-test'

    cloud_manifest = yaml_file('cloud_manifest', cloud_config_hash)
    deployment_manifest = yaml_file('whatevs_manifest', manifest_hash)

    target_and_login
    bosh_runner.run("upload release #{spec_asset('release_compilation_test.tgz')}")

    bosh_runner.run("update cloud-config #{cloud_manifest.path}")
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run('deploy')
    deploy_results = bosh_runner.run('task last --debug')

    goo_package_compile_regex = %r{compile_package.goo/0.1-dev.*(..method...compile_package.*)$}
    goo_package_compile_json = goo_package_compile_regex.match(deploy_results)[1]
    goo_package_compile = JSON.parse(goo_package_compile_json)
    expect(goo_package_compile['arguments'][2..3]).to eq(['goo', '0.1-dev.1'])
    expect(goo_package_compile['arguments'][4]).to have_key('boo')
    expect(goo_package_compile['arguments'][4].size).to eq(1)

    baz_package_compile_regex = %r{compile_package.baz/0.1-dev.*(..method...compile_package.*)$}
    baz_package_compile_json = baz_package_compile_regex.match(deploy_results)[1]
    baz_package_compile = JSON.parse(baz_package_compile_json)
    expect(baz_package_compile['arguments'][2..3]).to eq(['baz', '0.1-dev.1'])
    expect(baz_package_compile['arguments'][4]).to have_key('goo')
    expect(baz_package_compile['arguments'][4].size).to eq(1)

    foo_package_compile_regex = %r{compile_package.foo/0.1-dev.*(..method...compile_package.*)$}
    foo_package_compile_json = foo_package_compile_regex.match(deploy_results)[1]
    foo_package_compile = JSON.parse(foo_package_compile_json)
    expect(foo_package_compile['arguments'][2..4]).to eq(['foo', '0.1-dev.1', {}])
    expect(foo_package_compile['arguments'][4].size).to eq(0)

    bar_package_compile_regex = %r{compile_package.bar/0.1-dev.*(..method...compile_package.*)$}
    bar_package_compile_json = bar_package_compile_regex.match(deploy_results)[1]
    bar_package_compile = JSON.parse(bar_package_compile_json)
    expect(bar_package_compile['arguments'][2..3]).to eq(['bar', '0.1-dev.1'])
    expect(bar_package_compile['arguments'][4]).to have_key('foo')
    expect(bar_package_compile['arguments'][4].size).to eq(1)

    apply_spec_regex = %r{canary_update.foobar/0.*apply_spec_json.{5}(.+).{2}WHERE}
    apply_spec_json = apply_spec_regex.match(deploy_results)[1]
    apply_spec = JSON.parse(apply_spec_json.gsub('\"', '"'))
    packages = apply_spec['packages']
    packages.each do |key, value|
      expect(value['name']).to eq(key)
      expect(value['version']).to eq('0.1-dev.1')
      expect(value.keys).to match_array(%w(name version sha1 blobstore_id))
    end
    expect(packages.keys).to match_array(%w(foo bar baz))
  end

  it 'returns truncated output' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['template'] = 'fails_with_too_much_output'
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
end
