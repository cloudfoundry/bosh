require 'spec_helper'

describe 'post start script', type: :integration do
  with_reset_sandbox_before_each

  context 'when post start script is provided' do
    it 'successful runs post start script' do
      manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
        {
          'jobs' => [Bosh::Spec::Deployments.simple_job(
              name: 'job_with_templates_having_post_start_scripts',
              templates: [{'name' => 'job_with_post_start_script'}],
              instances: 1)]
        })
      deploy_from_scratch(manifest_hash: manifest)
      agent_id = director.vms.first.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_with_post_start_script/bin/post-start' script has successfully executed")

      post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
      expect(post_start_stdout).to match("message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message")

      post_start_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_post_start_script/post-start.stderr.log")
      expect(post_start_stderr).to match('message on stderr of job post-start script')
    end
  end
end
