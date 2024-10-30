require 'spec_helper'

describe 'dry run', type: :integration do
  with_reset_sandbox_before_each

  context 'when there are template errors' do
    it 'prints all template evaluation errors and does not register an event' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] = [
        {
          'name' => 'foobar',
          'jobs' => ['name' => 'foobar_with_bad_properties', 'release' => 'bosh-release'],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{
            'name' => 'a',
          }],
          'stemcell' => 'default',
        },
      ]

      output = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
        failure_expected: true,
        dry_run: true,
      )

      expect(output).to include <<~OUTPUT
        Error: Unable to render instance groups for deployment. Errors are:
          - Unable to render jobs for instance group 'foobar'. Errors are:
            - Unable to render templates for job 'foobar_with_bad_properties'. Errors are:
              - Error filling in template 'foobar_ctl' (line 8: Can't find property '["test_property"]')
              - Error filling in template 'drain.erb' (line 4: Can't find property '["dynamic_drain_wait1"]')
      OUTPUT

      expect(director.vms.length).to eq(0)
    end
  end

  context 'when there are no errors' do
    it 'returns some encouraging message but does not alter deployment' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups

      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
        dry_run: true,
      )

      expect(director.vms).to eq []
    end
  end

  it 'does not interfere with a successful deployment later' do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups

    deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
      dry_run: true,
    )

    _, exit_code = deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
      return_exit_code: true,
    )

    expect(exit_code).to eq(0)
  end
end
