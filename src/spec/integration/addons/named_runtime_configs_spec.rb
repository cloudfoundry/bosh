require 'spec_helper'

describe 'named runtime configs', type: :integration do
  with_reset_sandbox_before_each

  let(:named_runtime_config1) do
    {
      'releases' => [{ 'name' => 'test_release', 'version' => '1' }],
      'addons' => [{
        'name' =>  'addon11',
        'jobs' => [
          { 'name' => 'job_using_pkg_1', 'release' => 'test_release' },
        ],
      }],
      'tags' => {
        'foo' => 'smurfs',
        'bar' => 'gargaman',
      },
    }
  end

  let(:named_runtime_config2) do
    {
      'releases' => [{ 'name' => 'test_release_2', 'version' => '2' }],
      'addons' => [{
        'name' =>  'addon22',
        'jobs' => [
          { 'name' => 'job_using_pkg_2', 'release' => 'test_release_2' },
          { 'name' => 'job_using_pkg_5', 'release' => 'test_release_2' },
        ],
      }],
    }
  end

  before do
    default_runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
    named_runetime_config_file1 = yaml_file('runtime_config.yml', named_runtime_config1)
    named_runetime_config_file2 = yaml_file('runtime_config.yml', named_runtime_config2)

    expect(bosh_runner.run("update-runtime-config #{default_runtime_config_file.path}")).to include('Succeeded')
    expect(bosh_runner.run("update-runtime-config --name=rc_1 #{named_runetime_config_file1.path}")).to include('Succeeded')
    expect(bosh_runner.run("update-runtime-config --name=rc_2 #{named_runetime_config_file2.path}")).to include('Succeeded')

    bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")
    bosh_runner.run("upload-release #{asset_path('test_release.tgz')}")
    bosh_runner.run("upload-release #{asset_path('test_release_2.tgz')}")
  end

  it 'merges the releases & addons for a deploy' do
    deploy_from_scratch(
      manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
    )

    director.instances.each do |foobar_instance|
      expect(File.exist?(foobar_instance.job_path('foobar'))).to be_truthy
      expect(File.exist?(foobar_instance.job_path('dummy_with_package'))).to be_truthy
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to be_truthy
      expect(File.exist?(foobar_instance.job_path('job_using_pkg_1'))).to be_truthy
      expect(File.exist?(foobar_instance.job_path('job_using_pkg_2'))).to be_truthy
      expect(File.exist?(foobar_instance.job_path('job_using_pkg_5'))).to be_truthy
    end
  end

  it 'merges the tags key for a deploy' do
    deploy_from_scratch(
      manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
    )

    vms_cids = director.instances.map(&:vm_cid)
    invocations = current_sandbox.cpi.invocations.select do |invocation|
      invocation.method_name == 'set_vm_metadata' && vms_cids.include?(invocation.inputs['vm_cid'])
    end

    invocations.each do |invocation|
      expect(invocation['inputs']['metadata']['foo']).to eq('smurfs')
      expect(invocation['inputs']['metadata']['bar']).to eq('gargaman')
    end
  end

  context 'when a named runtime config is updated' do
    let(:named_runtime_config1) do
      {
        'releases' => [{ 'name' => 'test_release', 'version' => '1' }],
        'addons' => [{
          'name' =>  'addon11',
          'jobs' => [
            { 'name' => 'job_using_pkg_1', 'release' => 'test_release' },
          ],
        }],
      }
    end

    before do
      intermediate_invalid_manifest = {
        'releases' => [{ 'name' => 'test_release', 'version' => '1' }],
        'addons' => [{
          'name' =>  'addon11',
          'jobs' => [
            { 'name' => 'I do not exist', 'release' => 'not even once' },
          ],
        }],
      }
      intermediate_invalid_manifest_file = yaml_file('runtime_config.yml', intermediate_invalid_manifest)
      expect(bosh_runner.run("update-runtime-config --name=rc_1 #{intermediate_invalid_manifest_file.path}"))
        .to include('Succeeded')

      named_runtime_config1['addons'][0]['jobs'] = [
        { 'name' => 'job_using_pkg_3', 'release' => 'test_release' },
      ]

      named_runetime_config_file1 = yaml_file('runtime_config.yml', named_runtime_config1)
      expect(bosh_runner.run("update-runtime-config --name=rc_1 #{named_runetime_config_file1.path}")).to include('Succeeded')
    end

    it 'picks up the latest named runtime config when deploying' do
      deploy_from_scratch(
        manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      )

      director.instances.each do |foobar_instance|
        expect(File.exist?(foobar_instance.job_path('foobar'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('dummy_with_package'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_2'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_3'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_5'))).to be_truthy

        expect(File.exist?(foobar_instance.job_path('job_using_pkg_1'))).to be_falsy
      end
    end
  end

  context 'when tags are defined in multiple runtime configs' do
    before do
      named_runtime_config2['tags'] = { 'tags_name' => 'tag_value' }
      named_runetime_config_file2 = yaml_file('runtime_config.yml', named_runtime_config2)
      expect(bosh_runner.run("update-runtime-config --name=rc_2 #{named_runetime_config_file2.path}")).to include('Succeeded')
    end

    it 'fails when deploying' do
      output, exit_code = deploy_from_scratch(
        failure_expected: true,
        return_exit_code: true,
        manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to_not eq("Runtime config 'tags' key cannot be defined in multiple runtime configs.")
    end
  end
end
