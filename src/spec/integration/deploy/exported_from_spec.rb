require 'spec_helper'
require 'fileutils'

describe 'exported_from releases', type: :integration do
  with_reset_sandbox_before_each

  before do
    upload_cloud_config
    bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3001-aws-xen-centos-7-go_agent.tgz')}")
  end

  let(:jobs) do
    [{ 'name' => 'job_using_pkg_1', 'release' => 'test_release' }]
  end

  let(:manifest) do
    Bosh::Spec::Deployments.simple_manifest_with_instance_groups(
      jobs: jobs,
      name: 'foobar',
      stemcell: 'centos',
    ).tap do |manifest|
      manifest.merge!(
        'releases' => [{
          'name' => 'test_release',
          'version' => '1',
          'exported_from' => [
            { 'os' => 'centos-7', 'version' => '3001.1' },
          ],
        }],
        'stemcells' => [
          {
            'alias' => 'centos',
            'os' => 'centos-7',
            'version' => '3001',
          },
        ],
      )
    end
  end

  let(:targeted_release) { 'compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.1.tgz' }
  let(:decoy_newer_release) { 'compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.2.tgz' }

  context 'when new compiled releases have been uploaded after a deployment' do
    before do
      bosh_runner.run("upload-release #{asset_path(targeted_release)}")
      deploy(manifest_hash: manifest)

      bosh_runner.run("upload-release #{asset_path(decoy_newer_release)}")
    end

    it 'a no-op deploy does not update any VMs' do
      output = deploy(manifest_hash: manifest)
      expect(output).not_to include 'foobar'
    end
  end

  context 'when the exported_from points to a compiled package that does not exist' do
    before do
      bosh_runner.run("upload-release #{asset_path(decoy_newer_release)}")
    end

    it 'fails the deployment' do
      output = deploy(manifest_hash: manifest, failure_expected: true)
      expect(output).to include "Can't use release 'test_release/1'"
    end
  end

  context 'when the exported_from points to the wrong os' do
    before do
      bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3002-aws-xen-centos-7-go_agent.tgz')}")
    end

    it 'fails the deployment' do
      bosh_runner.run("upload-release #{asset_path(targeted_release)}")
      output = deploy(
        manifest_hash: manifest.tap { |manifest| manifest['stemcells'][0]['version'] = '3002' },
        failure_expected: true,
      )

      expect(output).to include "release 'test_release' must be exported from stemcell "\
      "'bosh-aws-xen-centos-7-go_agent/3002'. Release 'test_release' is exported from: 'centos-7/3001.1'."
    end
  end

  context 'when multiple instance groups use different stemcells' do
    before do
      bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3002-aws-xen-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload-release #{asset_path(targeted_release)}")
      bosh_runner.run("upload-release #{asset_path('compiled_releases/release-test_release-1-on-centos-7-stemcell-3002.tgz')}")
    end

    it 'is able to deploy' do
      manifest['stemcells'] << {
        'alias' => 'other-centos',
        'os' => 'centos-7',
        'version' => '3002',
      }
      manifest['instance_groups'] << Bosh::Spec::Deployments.simple_instance_group(
        :jobs => jobs,
        :name => 'foobar2',
        :stemcell => 'other-centos',
      )

      manifest['releases'][0]['exported_from'] << { 'os' => 'centos-7', 'version' => '3002' }

      deploy(manifest_hash: manifest)
    end
  end
end
