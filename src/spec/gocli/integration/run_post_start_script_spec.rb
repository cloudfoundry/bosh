require_relative '../spec_helper'

describe 'post start script', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest) do
    Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge(
      {
        'instance_groups' => [Bosh::Spec::NewDeployments.simple_instance_group(
                     name: 'job_with_templates_having_post_start_scripts',
                     jobs: [{'name' => 'job_with_post_start_script'}],
                     instances: 1,
                     properties: {:exit_code => exit_code})]
      })
  end
  let(:exit_code) { 0 }

  context 'when post start script is provided' do
    it 'successful runs post start script' do
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_with_post_start_script/bin/post-start' script has successfully executed")

      post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
      expect(post_start_stdout).to match("message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message")

      post_start_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_post_start_script/post-start.stderr.log")
      expect(post_start_stderr).to match('message on stderr of job post-start script')
    end

    it 'runs post-start script on subsequent deploys only when previous post-start scripts have failed' do
      manifest = Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
              'instance_groups' => [Bosh::Spec::NewDeployments.simple_instance_group(
                             name: 'job_with_templates_having_post_start_scripts',
                             jobs: [{'name' => 'job_with_post_start_script'}],
                             instances: 1,
                             properties: {'exit_code' => 1})]
          })
      expect{deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)}.to raise_error(RuntimeError, /result: 1 of 1 post-start scripts failed. Failed Jobs: job_with_post_start_script./)
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log.scan("/jobs/job_with_post_start_script/bin/post-start' script has failed with error").size).to eq(1)

      expect{deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)}.to raise_error(RuntimeError, /result: 1 of 1 post-start scripts failed. Failed Jobs: job_with_post_start_script./)
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      # We expect the script to run again, even though nothing has changed, just because it failed last time
      expect(agent_log.scan("/jobs/job_with_post_start_script/bin/post-start' script has failed with error").size).to eq(2)

      manifest = Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
              'instance_groups' => [Bosh::Spec::NewDeployments.simple_instance_group(
                             name: 'job_with_templates_having_post_start_scripts',
                             jobs: [{'name' => 'job_with_post_start_script'}],
                             instances: 1,
                             properties: {'exit_code' => 0})]
          })
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log.scan("/jobs/job_with_post_start_script/bin/post-start' script has successfully executed").size).to eq(1)

      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      # We expect the script to not run again because nothing has changed.
      expect(agent_log.scan("/jobs/job_with_post_start_script/bin/post-start' script has successfully executed").size).to eq(1)
    end
  end

  context 'when vm is recreated with cck --auto' do
    it 'skips running post-start script' do
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      bosh_runner.run('cloud-check --auto', deployment_name: 'simple')
      agent_id = director.instances.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to_not include("/jobs/job_with_post_start_script/bin/post-start' script has successfully executed")
    end
  end
end
