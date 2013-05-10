require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage package compilation' do
  include IntegrationExampleGroup

  describe 'package compilation' do
    it 'uses compile package cache for previously compiled packages' do
      stemcell_filename = spec_asset('valid_stemcell.tgz')

      simple_blob_store_path = current_sandbox.blobstore_storage_dir

      release_file = 'dev_releases/bosh-release-0.1-dev.tgz'
      release_filename = File.join(TEST_RELEASE_DIR, release_file)
      Dir.chdir(TEST_RELEASE_DIR) do
        FileUtils.rm_rf('dev_releases')
        run_bosh('create release --with-tarball', Dir.pwd)
      end

      deployment_manifest = yaml_file(
          'simple_manifest', Bosh::Spec::Deployments.simple_manifest)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')

      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload stemcell #{stemcell_filename}")
      run_bosh("upload release #{release_filename}")
      run_bosh('deploy')
      dir_glob = Dir.glob(File.join(simple_blob_store_path, '**/*'))
      dir_glob.detect do |cache_item|
        cache_item =~ /foo-/
      end.should_not be_nil

      # delete release so that the compiled packages are removed from the local blobstore
      run_bosh('delete deployment simple')
      run_bosh('delete release bosh-release')

      # deploy again
      run_bosh("upload release #{release_filename}")
      run_bosh('deploy')

      event_log = run_bosh('task last --event --raw')
      event_log.should match /Downloading '.+' from global cache/
      event_log.should_not match /Compiling packages/
    end

    it 'compiles explicit requirements and dependencies recursively, but only applies explicit requirements to jobs' do
      deployment_manifest_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_manifest_hash['jobs'][0]['template'] = ['foobar', 'goobaz']
      deployment_manifest_hash['jobs'][0]['instances'] = 1
      deployment_manifest_hash['resource_pools'][0]['size'] = 1

      deployment_manifest_hash['release']['name'] = 'compilation-test'

      deployment_manifest = yaml_file('whatevs_manifest', deployment_manifest_hash)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')

      run_bosh("upload release #{spec_asset('release_compilation_test.tgz')}")

      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      run_bosh('deploy')
      deploy_results = run_bosh('task last --debug')

      goo_package_compile_regex = %r{compile_package.goo/0.1-dev.*(..method...compile_package.*)$}
      goo_package_compile_json = goo_package_compile_regex.match(deploy_results)[1]
      goo_package_compile = JSON.parse(goo_package_compile_json)
      goo_package_compile['arguments'][2..3].should == ['goo', '0.1-dev.1']
      goo_package_compile['arguments'][4].should have_key('boo')

      baz_package_compile_regex = %r{compile_package.baz/0.1-dev.*(..method...compile_package.*)$}
      baz_package_compile_json = baz_package_compile_regex.match(deploy_results)[1]
      baz_package_compile = JSON.parse(baz_package_compile_json)
      baz_package_compile['arguments'][2..3].should == ['baz', '0.1-dev.1']
      baz_package_compile['arguments'][4].should have_key('goo')
      baz_package_compile['arguments'][4].should have_key('boo')

      foo_package_compile_regex = %r{compile_package.foo/0.1-dev.*(..method...compile_package.*)$}
      foo_package_compile_json = foo_package_compile_regex.match(deploy_results)[1]
      foo_package_compile = JSON.parse(foo_package_compile_json)
      foo_package_compile['arguments'][2..4].should == ['foo', '0.1-dev.1', {}]

      bar_package_compile_regex = %r{compile_package.bar/0.1-dev.*(..method...compile_package.*)$}
      bar_package_compile_json = bar_package_compile_regex.match(deploy_results)[1]
      bar_package_compile = JSON.parse(bar_package_compile_json)
      bar_package_compile['arguments'][2..3].should == ['bar', '0.1-dev.1']
      bar_package_compile['arguments'][4].should have_key('foo')

      apply_spec_regex = %r{canary_update.foobar/0.*apply_spec_json.{5}(.+).{2}WHERE}
      apply_spec_json = apply_spec_regex.match(deploy_results)[1]
      apply_spec = JSON.parse(apply_spec_json)
      packages = apply_spec['packages']
      packages.each do |key, value|
        value['name'].should == key
        value['version'].should == '0.1-dev.1'
        value.keys.should =~ ['name', 'version', 'sha1', 'blobstore_id']
      end
      packages.keys.should =~ ['foo', 'bar', 'baz']
    end
  end
end
