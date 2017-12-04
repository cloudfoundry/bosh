require_relative '../spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }

  context 'when generating a tarball' do
    let!(:release_file) { Tempfile.new('release.tgz') }
    after { release_file.delete }

    it 'generates release and deploys it via simple manifest' do
      # Test release created with bosh (see spec/assets/test_release_template)
      Dir.chdir(ClientSandbox.test_release_dir) do
        FileUtils.rm_rf('dev_releases')
        bosh_runner.run_in_current_dir("create-release --tarball=#{release_file.path}")
      end

      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)

      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload-stemcell #{stemcell_filename}")
      bosh_runner.run("upload-release #{release_file.path}")

      expect(bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')).to include("Using deployment 'simple'")
      expect(bosh_runner.run('cloud-check --report', deployment_name: 'simple')).to match(/0 problems/)
    end
  end

  describe 'bosh deploy' do
    let(:old_cloud_config) do
      Bosh::Spec::NewDeployments.simple_cloud_config
    end

    let(:new_cloud_config) do
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config['vm_types'] = [
        {
          'name' => 'a',
          'cloud_properties' => {
            'my-property' => 'foo'
          }
        },
        Bosh::Spec::NewDeployments.compilation_vm_type
      ]
      cloud_config
    end



    context 'given two deployments from one release' do
      it 'is successful' do
        release_filename = spec_asset('test_release.tgz')
        minimal_manifest = Bosh::Spec::NewDeployments.minimal_manifest
        deployment_manifest = yaml_file('minimal_deployment', minimal_manifest)

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)

        bosh_runner.run("upload-release #{release_filename}")
        bosh_runner.run("upload-stemcell #{stemcell_filename}")
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: minimal_manifest['name'])

        minimal_manifest['name'] = 'minimal2'
        deployment_manifest = yaml_file('minimal2', minimal_manifest)

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: minimal_manifest['name'])
        expect_table('deployments', [{'name' => 'minimal', 'release_s' => 'test_release/1', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}, {'name' => 'minimal2', 'release_s' => 'test_release/1', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}])
      end

      context 'properties from first deployment are modified in second deployment' do
        let(:old_manifest) do
          old_manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
          old_manifest['releases'].first['version'] = '0+dev.1' # latest is converted to release version in new format

          old_spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'instanceGroup1',
            jobs: [{'name' => 'foobar_without_packages'}]
          )
          old_spec['properties'] = {
            'foobar' => {'foo' => "baaar\nbaz"},
            'array_property' => ['value1', 'value2'],
            'hash_array_property' => [{'a' => 'b'}, {'b' => 'c'}, {'yy' => 'z'}],
            'name_range_hash_array_property' => [{'name' => 'old_name'}, {'range' => 'old_range'}],
            'old_property' => 'delete_me'}

          old_manifest['instance_groups'] = [old_spec]
          old_manifest
        end

        let(:new_manifest) do
          new_manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'instanceGroup1',
            jobs: [{'name' => 'foobar_without_packages'}]
          )
          spec['properties'] = {
            'foobar' => {'foo' => "bar\nbaz"},
            'array_property' => ['valuee1', 'value2', 'value3'],
            'hash_array_property' => [{'a' => 'b'}, {'b' => 'd'}, {'e' => 'f'}],
            'name_range_hash_array_property' => [{'name' => 'new_name'}, {'range' => 'new_range'}],
            'new_property' => 'add_me',
            'multi-line' => '---this property---
spans multiple
lines'}

          new_manifest['instance_groups'] = [spec]
          new_manifest['releases'].first['version'] = 'latest'
          new_manifest
        end

        it 'shows a diff of the manifest with cloud config changes and redacted properties' do
          deploy_from_scratch(manifest_hash: old_manifest, cloud_config_hash: old_cloud_config)
          upload_cloud_config(cloud_config_hash: new_cloud_config)
          output = deploy_simple_manifest(manifest_hash: new_manifest, no_color: true)

          # some IDEs strip out excess whitespace on empty lines; workaround
          output.gsub!(/^\s+$/, '')

          expect(output).to_not include('stemcell')
          expect(output).to_not include('releases')

          expect(output).to include('  vm_types:
  - name: a
    cloud_properties:
+     my-property: foo

  instance_groups:
  - name: instanceGroup1
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
            deploy_from_scratch(manifest_hash: old_manifest, cloud_config_hash: old_cloud_config)
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
        prepare_for_deploy(cloud_config_hash: old_cloud_config)
        deployment_manifest = yaml_file('simple', Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)
        bosh_runner.run_interactively("deploy #{deployment_manifest.path}", deployment_name: 'simple', no_color: true) do |runner|
          expect(runner).to have_output 'Continue?'

          upload_cloud_config(cloud_config_hash: new_cloud_config)

          runner.send_keys 'yes'
          expect(runner).to have_output "Succeeded"
        end

        output = deploy_simple_manifest(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)
        expect(output).to include(<<-DIFF
  vm_types:
  - name: a
    cloud_properties:
+     my-property: foo
        DIFF
        )
      end
    end

    context 'when using cpi config for a new deployment' do
      it 'deploys to multiple cpis' do
        cpi_path = current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI)

        cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs_and_cpis)
        cpi_config_manifest = yaml_file('cpi_manifest', Bosh::Spec::NewDeployments.simple_cpi_config(cpi_path))

        instance_group = Bosh::Spec::NewDeployments.simple_instance_group(:azs => ['z1', 'z2'])
        deployment = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group])
        deployment_manifest = yaml_file('deployment_manifest', deployment)

        create_and_upload_test_release
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
        bosh_runner.run("upload-stemcell #{stemcell_filename}")
        output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
        expect(output).to include("Using deployment 'simple'")
        expect(output).to include('Succeeded')

        expect_table('stemcells', [
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => 'cpi-name1',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => 'cpi-name2',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },

        ])
      end
    end

    context 'when switching to cpi config for existing deployment' do
      it 'deploys to multiple cpis' do
        create_and_upload_test_release

        # deploy without cpi config
        cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)
        deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)

        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
        bosh_runner.run("upload-stemcell #{stemcell_filename}")

        output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
        expect(output).to include("Using deployment 'simple'")
        expect(output).to include('Succeeded')

        expect_table('stemcells', [
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => '',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },
        ])

        # now deploy with cpi config
        cpi_path = current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI)
        cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs_and_cpis)
        cpi_config_manifest = yaml_file('cpi_manifest', Bosh::Spec::NewDeployments.simple_cpi_config(cpi_path))

        instance_group = Bosh::Spec::NewDeployments.simple_instance_group(:azs => ['z1', 'z2'])
        deployment = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group])
        deployment_manifest = yaml_file('deployment_manifest', deployment)

        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

        expect{
          bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
        }.to raise_error /Required stemcell {"name"=>"ubuntu-stemcell", "version"=>"1"} not found for cpi/

        bosh_runner.run("upload-stemcell --fix #{stemcell_filename}")

        output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
        expect(output).to include("Using deployment 'simple'")
        expect(output).to include('Succeeded')

        expect_table('stemcells', [
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => '',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => 'cpi-name1',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },
            {
                'name' => 'ubuntu-stemcell',
                'os' => 'toronto-os',
                'version' => '1*',
                'cpi' => 'cpi-name2',
                'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
            },

        ])
      end
    end
  end

  describe 'bosh deployments' do
    it 'lists deployment details' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::NewDeployments.minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)

      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload-stemcell #{stemcell_filename}")
      bosh_runner.run("upload-release #{release_filename}")

      out = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'minimal')
      expect(out).to include("Using deployment 'minimal'")

      expect_table('deployments', [{'name' => 'minimal', 'release_s' => 'test_release/1', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}])
    end

    context 'when cloud config is updated and deploying has failed' do
      it 'shows cloud config as still outdated' do
        deployment_manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        deployment_manifest = yaml_file('simple', deployment_manifest_hash)
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config_hash)

        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

        create_and_upload_test_release
        upload_stemcell

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')

        deployment_manifest_hash['instance_groups'].first['jobs'].first['name'] = 'fails_with_too_much_output'
        deployment_manifest = yaml_file('simple', deployment_manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.20']
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config_hash)
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

        bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple', failure_expected: true)

        expect_table('deployments', [
            {
                'name' => 'simple',
                'release_s' => 'bosh-release/0+dev.1',
                'stemcell_s' => 'ubuntu-stemcell/1',
                'team_s' => '',
                'cloud_config' => 'outdated'
            }
        ])
      end
    end

  end

  describe 'bosh delete deployment' do
    it 'deletes an existing deployment' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::NewDeployments.minimal_manifest_with_ubuntu_stemcell)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)

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
