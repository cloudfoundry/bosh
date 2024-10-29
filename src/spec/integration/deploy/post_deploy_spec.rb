require 'spec_helper'

describe 'post deploy scripts', type: :integration do
  context 'when post-deploy scripts are supported' do
    with_reset_sandbox_before_each

    before do
      upload_cloud_config(cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
      upload_stemcell
    end

    context 'when the post-deploy scripts are valid' do
      let(:manifest) do
        Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
          'instance_groups' => [Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'job_with_post_deploy_script',
            jobs: [
              { 'name' => 'job_1_with_post_deploy_script', 'release' => 'bosh-release' },
              { 'name' => 'job_2_with_post_deploy_script', 'release' => 'bosh-release' },
            ],
            instances: 1,
          ), Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'another_job_with_post_deploy_script',
            jobs: [
              { 'name' => 'job_1_with_post_deploy_script', 'release' => 'bosh-release' },
              { 'name' => 'job_2_with_post_deploy_script', 'release' => 'bosh-release' },
            ],
            instances: 1,
          )],
        )
      end

      before { create_and_upload_test_release }

      it 'runs the post-deploy scripts' do
        deploy(manifest_hash: manifest)

        agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        expect(agent_log).to include("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log"

        job_1_stdout = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stdout.log'))
        expect(job_1_stdout).to match(
          "message on stdout of job 1 post-deploy script\n" \
          'template interpolation works in this script: this is post_deploy_message_1',
        )

        job_1_stderr = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stderr.log'))
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        job_2_stdout = File.read(File.join(log_path, 'job_2_with_post_deploy_script/post-deploy.stdout.log'))
        expect(job_2_stdout).to match('message on stdout of job 2 post-deploy script')
      end

      it 'does not run post-deploy scripts on stopped vms' do
        deploy(manifest_hash: manifest)

        agent_id1 = director.instance('job_with_post_deploy_script', '0').agent_id
        agent_id2 = director.instance('another_job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id1}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id2}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)

        stop_job('another_job_with_post_deploy_script/0')

        agent_id1 = director.instance('job_with_post_deploy_script', '0').agent_id
        agent_id2 = director.instance('another_job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id1}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(2)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(2)

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id2}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
      end

      context 'when hm is running', hm: true do
        with_reset_hm_before_each

        it 'runs the post-deploy script when a vm is resurrected' do
          deploy(manifest_hash: manifest)

          agent_id = director.instance('job_with_post_deploy_script', '0').agent_id
          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
          expect(
            agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
          ).to eq(1)

          resurrected_instance = director.kill_vm_and_wait_for_resurrection(director.instance('job_with_post_deploy_script', '0'))

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{resurrected_instance.agent_id}.log")
          expect(
            agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
          ).to eq(1)
        end
      end
    end

    context 'when the post-deploy scripts exit with error' do
      let(:manifest) do
        Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
          'instance_groups' => [Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'job_with_post_deploy_script',
            jobs: [
              { 'name' => 'job_1_with_post_deploy_script', 'release' => 'bosh-release' },
              { 'name' => 'job_3_with_broken_post_deploy_script', 'release' => 'bosh-release' },
            ],
            instances: 1,
          )],
        )
      end

      before { create_and_upload_test_release }

      it 'exits with error if post-deploy errors, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log' do
        expect do
          deploy(manifest_hash: manifest)
        end.to raise_error(
          RuntimeError,
          Regexp.new(
            'result: 1 of 2 post-deploy scripts failed. Failed Jobs: job_3_with_broken_post_deploy_script. ' \
            'Successful Jobs: job_1_with_post_deploy_script.',
          ),
        )

        agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        expect(agent_log).to include("/jobs/job_3_with_broken_post_deploy_script/bin/post-deploy' script has failed with error")
        log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log"

        job_1_stdout = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stdout.log'))
        expect(job_1_stdout).to match(
          "message on stdout of job 1 post-deploy script\n" \
          'template interpolation works in this script: this is post_deploy_message_1',
        )

        job_1_stderr = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stderr.log'))
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        job_3_stdout = File.read(File.join(log_path, 'job_3_with_broken_post_deploy_script/post-deploy.stdout.log'))
        expect(job_3_stdout).to match('message on stdout of job 3 post-deploy script')

        job_3_stderr = File.read(File.join(log_path, 'job_3_with_broken_post_deploy_script/post-deploy.stderr.log'))
        expect(job_3_stderr).not_to be_empty
      end
    end

    context 'when nothing has changed in the deployment it does not run the post-deploy script' do
      let(:manifest) do
        Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
          'instance_groups' => [Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'job_with_post_deploy_script',
            jobs: [
              { 'name' => 'job_1_with_post_deploy_script', 'release' => 'bosh-release' },
              { 'name' => 'job_2_with_post_deploy_script', 'release' => 'bosh-release' },
            ],
            instances: 1,
          ),
                                Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
                                  name: 'job_with_errand',
                                  jobs: [
                                    { 'name' => 'errand1', 'release' => 'bosh-release' },
                                  ],
                                  instances: 1,
                                  lifecycle: 'errand',
                                )],
        )
      end

      before { create_and_upload_test_release }

      it 'should not run the post deploy script if no changes have been made in deployment' do
        deploy(manifest_hash: manifest)
        agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)

        deploy(manifest_hash: manifest)
        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
      end

      it 'should not run post deploy script on jobs with no vm_cid' do
        deploy(manifest_hash: manifest)
        agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(
          agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        expect(
          agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size,
        ).to eq(1)
        log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log"

        job_1_stdout = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stdout.log'))
        expect(job_1_stdout).to match(
          "message on stdout of job 1 post-deploy script\n" \
          'template interpolation works in this script: this is post_deploy_message_1',
        )

        job_1_stderr = File.read(File.join(log_path, 'job_1_with_post_deploy_script/post-deploy.stderr.log'))
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        expect(File.file?(File.join(log_path, 'job_with_errand/post-deploy.stdout.log'))).to be_falsey
      end
    end
  end
end
