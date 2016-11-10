require_relative '../spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }

  it 'generates release and deploys it via simple manifest' do
    # Test release created with bosh (see spec/assets/test_release_template)
    release_filename = Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')
      output = bosh_runner.run_in_current_dir('create-release --tarball')
      parse_release_tarball_path(output)
    end

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)

    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
    bosh_runner.run("upload-release #{release_filename}")

    expect(bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')).to include("Using deployment 'simple'")
    expect(bosh_runner.run('cloud-check --report', deployment_name: 'simple')).to match(/0 problems/)
  end

  describe 'bosh deploy' do
    context 'given two deployments from one release' do
      it 'is successful' do
        release_filename = spec_asset('test_release.tgz')
        minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
        deployment_manifest = yaml_file('minimal_deployment', minimal_manifest)

        cloud_config = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config['resource_pools'][0].delete('size')
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)

        bosh_runner.run("upload-release #{release_filename}")
        bosh_runner.run("upload-stemcell #{stemcell_filename}")
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: minimal_manifest['name'])

        minimal_manifest['name'] = 'minimal2'
        deployment_manifest = yaml_file('minimal2', minimal_manifest)

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: minimal_manifest['name'])
        expect_table('deployments', [{'Name' => 'minimal', 'Release(s)' => 'test_release/1', 'Stemcell(s)' => 'ubuntu-stemcell/1', 'Cloud Config' => 'latest'}, {'Name' => 'minimal2', 'Release(s)' => 'test_release/1', 'Stemcell(s)' => 'ubuntu-stemcell/1', 'Cloud Config' => 'latest'}])
      end

      context 'properties from first deployment are modified in second deployment' do
        let(:old_manifest) do
          old_manifest = Bosh::Spec::Deployments.simple_manifest
          old_manifest['releases'].first['version'] = '0+dev.1' # latest is converted to release version in new format

          old_job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'job1',
            templates: [{'name' => 'foobar_without_packages'}]
          )
          old_job_spec['properties'] = {
            'foobar' => {'foo' => "baaar\nbaz"},
            'array_property' => ['value1', 'value2'],
            'hash_array_property' => [{'a' => 'b'}, {'b' => 'c'}, {'yy' => 'z'}],
            'name_range_hash_array_property' => [{'name' => 'old_name'}, {'range' => 'old_range'}],
            'old_property' => 'delete_me'}

          old_manifest['jobs'] = [old_job_spec]
          old_manifest
        end

        let(:new_manifest) do
          new_manifest = Bosh::Spec::Deployments.simple_manifest

          new_job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'job1',
            templates: [{'name' => 'foobar_without_packages'}]
          )
          new_job_spec['properties'] = {
            'foobar' => {'foo' => "bar\nbaz"},
            'array_property' => ['valuee1', 'value2', 'value3'],
            'hash_array_property' => [{'a' => 'b'}, {'b' => 'd'}, {'e' => 'f'}],
            'name_range_hash_array_property' => [{'name' => 'new_name'}, {'range' => 'new_range'}],
            'new_property' => 'add_me',
            'multi-line' => '---this property---
spans multiple
lines'}

          new_manifest['jobs'] = [new_job_spec]
          new_manifest['releases'].first['version'] = 'latest'
          new_manifest
        end

        let(:new_cloud_config) do
          new_cloud_config = Bosh::Spec::Deployments.simple_cloud_config
          new_cloud_config['resource_pools'] = [
            {
              'name' => 'a',
              'cloud_properties' => {'name' => 'new_property', 'size' => 'large'},
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => 'latest',
              },
            }
          ]
          new_cloud_config
        end

        it 'shows a diff of the manifest with cloud config changes and redacted properties' do
          deploy_from_scratch(manifest_hash: old_manifest)
          upload_cloud_config(cloud_config_hash: new_cloud_config)
          output = deploy_simple_manifest(manifest_hash: new_manifest, no_color: true)

          # some IDEs strip out excess whitespace on empty lines; workaround
          output.gsub!(/^\s+$/, '')

          expect(output).to_not include('stemcell')
          expect(output).to_not include('releases')

          expect(output).to include('  resource_pools:
  - name: a
    cloud_properties:
+     name: new_property
+     size: large
-   env:
-     bosh:
-       password: "<redacted>"

  jobs:
  - name: job1
    properties:
      array_property:
+     - "<redacted>"
+     - "<redacted>"
-     - "<redacted>"
      foobar:
-       foo: "<redacted>"
+       foo: "<redacted>"
      hash_array_property:
+     - b: "<redacted>"
+     - e: "<redacted>"
-     - b: "<redacted>"
-     - yy: "<redacted>"
      name_range_hash_array_property:
+     - name: "<redacted>"
+     - range: "<redacted>"
-     - name: "<redacted>"
-     - range: "<redacted>"
-     old_property: "<redacted>"
+     multi-line: "<redacted>"
+     new_property: "<redacted>"
')
        end

        context 'option --no-redact' do
          it 'shows a diff of the manifest with cloud config changes and not redacted properties' do
            deploy_from_scratch(manifest_hash: old_manifest)
            upload_cloud_config(cloud_config_hash: new_cloud_config)
            output = deploy_simple_manifest(manifest_hash: new_manifest, no_color: true, no_redact: true)

            expect(output).to_not include('stemcell')
            expect(output).to_not include('releases')
            expect(output).to_not match(/<redacted>/)
          end
        end
      end
    end

    context 'when cloud config is updated during deploy' do
      it 'deploys with cloud config shown in diff' do
        prepare_for_deploy
        deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
        bosh_runner.run_interactively("deploy #{deployment_manifest.path}", deployment_name: 'simple', no_color: true) do |runner|
          expect(runner).to have_output 'Continue?'

          new_cloud_config = Bosh::Spec::Deployments.simple_cloud_config
          new_cloud_config['resource_pools'] = [
            {
              'name' => 'a',
              'cloud_properties' => {'name' => 'new_property'},
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => 'latest',
              },
            }
          ]
          upload_cloud_config(cloud_config_hash: new_cloud_config)


          runner.send_keys 'yes'
          expect(runner).to have_output "Succeeded"
        end

        output = deploy_simple_manifest
        expect(output).to include(<<-DIFF
  resource_pools:
  - name: a
    cloud_properties:
+     name: new_property
        DIFF
        )
      end
    end
  end

  describe 'bosh deployments' do
    it 'lists deployment details' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)

      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload-stemcell #{stemcell_filename}")
      bosh_runner.run("upload-release #{release_filename}")

      out = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'minimal')
      expect(out).to include("Using deployment 'minimal'")

      expect_table('deployments', [{'Name' => 'minimal', 'Release(s)' => 'test_release/1', 'Stemcell(s)' => 'ubuntu-stemcell/1', 'Cloud Config' => 'latest'}])
    end
  end

  describe 'bosh delete deployment' do
    it 'deletes an existing deployment' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)

      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload-stemcell #{stemcell_filename}")
      bosh_runner.run("upload-release #{release_filename}")

      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'minimal')
      bosh_runner.run('delete-deployment', deployment_name: 'minimal')
      expect_table('deployments', [])
    end

    it 'can idempotently delete a non-existent deployment' do
      bosh_runner.run('delete-deployment', deployment_name: 'non-existent-deployment')
      bosh_runner.run('delete-deployment', deployment_name: 'non-existent-deployment')
    end
  end
end
