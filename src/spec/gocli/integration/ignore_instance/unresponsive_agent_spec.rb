require 'spec_helper'

describe 'unresponsive agent', type: :integration do
  with_reset_sandbox_before_each

  # TODO: Remove test when done removing v1 manifest support
  xcontext 'when using v1 manifest' do
    it 'should timeout and fail' do
      manifest_hash = Bosh::Spec::Deployments.legacy_manifest

      manifest_hash['jobs'].clear
      manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job(name: 'foobar1', instances: 2)

      deploy_from_scratch(manifest_hash: manifest_hash, legacy: true)

      initial_instances = director.instances
      foobar1_instance1 = initial_instances[0]
      foobar1_instance2 = initial_instances[1]
      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      foobar1_instance1.kill_agent

      manifest_hash['jobs'].clear
      manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
        name: 'foobar1',
        templates: [{ 'name' => 'job_1_with_pre_start_script' }],
        instances: 2,
      )

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        failure_expected: true,
        return_exit_code: true,
        legacy: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include("Timed out sending 'get_state'")

      modified_instances = director.instances
      modified_foobar1_instance1 = modified_instances.select { |i| i.id == foobar1_instance1.id }.first
      modified_foobar1_instance2 = modified_instances.select { |i| i.id == foobar1_instance2.id }.first

      expect(modified_foobar1_instance1.last_known_state).to eq('unresponsive agent')
      expect(modified_foobar1_instance2.last_known_state).to eq('running')
    end
  end

  context 'when using v2 manifest' do
    it 'should not contact the VM and deploys successfully' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group(name: 'foobar1', instances: 2)

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      initial_instances = director.instances
      foobar1_instance1 = initial_instances[0]
      foobar1_instance2 = initial_instances[1]
      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      foobar1_instance1.kill_agent

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [{ 'name' => 'job_1_with_pre_start_script' }],
        instances: 2,
      )

      output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      expect(output).to include('Warning: You have ignored instances. They will not be changed.')
      expect(output).to_not include("Updating instance foobar1: foobar1/#{foobar1_instance1.id} (#{foobar1_instance1.index})")
      expect(output).to include("Updating instance foobar1: foobar1/#{foobar1_instance2.id} (#{foobar1_instance2.index})")

      modified_instances = director.instances
      modified_foobar1_instance1 = modified_instances.select { |i| i.id == foobar1_instance1.id }.first
      modified_foobar1_instance2 = modified_instances.select { |i| i.id == foobar1_instance2.id }.first

      expect(modified_foobar1_instance1.last_known_state).to eq('unresponsive agent')
      expect(modified_foobar1_instance2.last_known_state).to eq('running')
    end
  end
end
