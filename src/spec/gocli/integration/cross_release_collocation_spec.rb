require_relative '../spec_helper'

describe 'collocating templates from multiple releases', type: :integration do
  with_reset_sandbox_before_each

  context 'successfully collocating templates from different releases' do
    let(:manifest) do
      {
        'releases' => [
          { 'name' => 'dummy', 'version' => 'latest' },
          { 'name' => 'dummy2', 'version' => 'latest' },
        ],
        'instance_groups' => [{
          'name' => 'foobar',
          'jobs' => [
            { 'name' => 'dummy_with_package', 'release' => 'dummy' },
            { 'name' => 'dummy',              'release' => 'dummy2' },
          ],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
          'stemcell' => 'default'
        }]
      }
    end
    let(:manifest_for_properties) do
      {
        'releases' => [
          {'name' => 'dummy', 'version' => 'latest'},
          {'name' => 'bosh-release', 'version' => '0.1-dev'},
        ],
        'instance_groups' => [{
          'name' => 'foobar',
          'jobs' => [
            {'name' => 'dummy_with_properties', 'release' => 'dummy'},
            {'name' => 'foobar', 'release' => 'bosh-release'},
          ],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{'name' => 'a'}],
          'stemcell' => 'default'
        }]
      }
    end

    it 'shows correct versions and names in templates' do
      bosh_runner.run("upload-release #{spec_asset('dummy-release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")

      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)
      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge(manifest_for_properties)

      # We manually change the deployment manifest release version, because of weird issue where
      # the uploaded release version is `0+dev.1` and the release version in the deployment manifest
      # is `0.1-dev`, similar to links_spec
      manifest_hash['releases'][1]['version'] = '0+dev.1'

      deployment_name = manifest_hash['name']
      deployment_manifest = yaml_file('simple', manifest_hash)

      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: deployment_name)

      foobar_instance = director.instance('foobar', '0')

      foobar_template = foobar_instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(foobar_template).to include('release_name=bosh-release')
      expect(foobar_template).to include('release_version=0+dev.1')

      dummy_template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(dummy_template).to include('release_name=dummy')
      expect(dummy_template).to include('release_version=0+dev.2')

      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      bosh_runner.run('cloud-check --auto', deployment_name: deployment_name)

      foobar_instance = director.instance('foobar', '0')
      foobar_template = foobar_instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(foobar_template).to include('release_name=bosh-release')
      expect(foobar_template).to include('release_version=0+dev.1')

      dummy_template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(dummy_template).to include('release_name=dummy')
      expect(dummy_template).to include('release_version=0+dev.2')
    end

    it 'successfully deploys' do
      bosh_runner.run("upload-release #{spec_asset('dummy-release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")

      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)
      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge(manifest)
      deployment_name = manifest_hash['name']
      deployment_manifest = yaml_file('simple', manifest_hash)
      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: deployment_name)
    end
  end

  context 'when 2 templates depend on packages with the same name from different releases' do
    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

    context 'and the fingerprints match' do
      before do
        manifest['releases'] = [
          { 'name' => 'test_release', 'version' => 'latest' },
          { 'name' => 'test_release_2', 'version' => 'latest' }
        ]
        manifest['instance_groups'][0]['jobs'] = [
          { 'name' => 'job_using_pkg_1_and_2', 'release' => 'test_release' },
          { 'name' => 'job_using_pkg_1', 'release' => 'test_release_2' }
        ]

        bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
        bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")
      end

      it 'allows the co-located jobs to share the same package' do
        deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

        instance = director.instances.first
        agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
        expect(Dir.entries(File.join(agent_dir, 'data', 'packages'))).to match_array(%w[. .. pkg_1 pkg_2])
        # need to check for 3 entries to account for . and ..
        expect(Dir.entries(File.join(agent_dir, 'data', 'packages', 'pkg_1')).size).to eq(3)
        expect(Dir.entries(File.join(agent_dir, 'data', 'packages', 'pkg_2')).size).to eq(3)
      end
    end

    context 'and the fingerprints differ' do
      before do
        manifest['releases'] = [
          { 'name' => 'test_release', 'version' => 'latest' },
          { 'name' => 'test_release_with_modified_fingerprint_for_pkg_1', 'version' => 'latest' }
        ]
        manifest['instance_groups'][0]['jobs'] = [
          { 'name' => 'job_using_pkg_1_and_2', 'release' => 'test_release' },
          { 'name' => 'job_using_pkg_1', 'release' => 'test_release_with_modified_fingerprint_for_pkg_1' }
        ]

        bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
        bosh_runner.run("upload-release #{spec_asset('test_release_with_modified_fingerprint_for_pkg_1.tgz')}")
      end

      it 'refuses to deploy' do
        output = deploy_from_scratch(
          manifest_hash: manifest,
          cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config,
          failure_expected: true
        )

        expect(output).to match(%r[Package name collision detected in instance group 'foobar': job 'test_release/job_using_pkg_1_and_2' depends on package 'test_release/pkg_1',])
      end
    end
  end
end
