
require_relative '../spec_helper'
require 'fileutils'

describe 'deploy multiple releases', type: :integration do
  context 'when co-locating packages with the same name' do
    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
    with_reset_sandbox_before_each

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
      expect(Dir.entries(File.join(agent_dir, 'data', 'packages'))).to eq(%w[. .. pkg_1 pkg_2])
      # need to check for 3 entries to account for . and ..
      expect(Dir.entries(File.join(agent_dir, 'data', 'packages', 'pkg_1')).size).to eq(3)
      expect(Dir.entries(File.join(agent_dir, 'data', 'packages', 'pkg_2')).size).to eq(3)
    end
  end
end
