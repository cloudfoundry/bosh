require 'spec_helper'

describe 'pre-start scripts', type: :integration do
  with_reset_sandbox_before_each

  before do
    upload_cloud_config(cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
    upload_stemcell
  end

  context 'when the pre-start scripts are valid' do
    let(:manifest) do
      Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
        'instance_groups' => [Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'job_with_templates_having_prestart_scripts',
          jobs: [
            {
              'name' => 'job_1_with_pre_start_script',
              'release' => 'bosh-release',
            },
            {
              'name' => 'job_2_with_pre_start_script',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )],
      )
    end

    before { create_and_upload_test_release }

    it 'runs the pre-start scripts, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
      deploy(manifest_hash: manifest)

      agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_1_with_pre_start_script/bin/pre-start' script has successfully executed")
      expect(agent_log).to include("/jobs/job_2_with_pre_start_script/bin/pre-start' script has successfully executed")
      log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/"

      job_1_stdout = File.read(File.join(log_path, '/job_1_with_pre_start_script/pre-start.stdout.log'))
      expect(job_1_stdout).to match(
        "message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1",
      )

      job_1_stderr = File.read(File.join(log_path, '/job_1_with_pre_start_script/pre-start.stderr.log'))
      expect(job_1_stderr).to match('message on stderr of job 1 pre-start script')

      job_2_stdout = File.read(File.join(log_path, '/job_2_with_pre_start_script/pre-start.stdout.log'))
      expect(job_2_stdout).to match('message on stdout of job 2 pre-start script')
    end
  end

  it 'should append the logs to the previous pre-start logs' do
    manifest = Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
      'releases' => [{
        'name' => 'release_with_prestart_script',
        'version' => '1',
      }],
      'instance_groups' => [
        Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'job_with_templates_having_prestart_scripts',
          jobs: [
            {
              'name' => 'job_1_with_pre_start_script',
              'release' => 'release_with_prestart_script',
            },
          ],
          instances: 1,
        ),
      ],
    )
    bosh_runner.run("upload-release #{asset_path('pre_start_script_releases/release_with_prestart_script-1.tgz')}")
    deploy(manifest_hash: manifest)

    # re-upload a different release version to make the pre-start scripts run
    manifest['releases'][0]['version'] = '2'
    bosh_runner.run("upload-release #{asset_path('pre_start_script_releases/release_with_prestart_script-2.tgz')}")
    deploy(manifest_hash: manifest)

    agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id
    log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/"

    job_1_stdout = File.read(File.join(log_path, '/job_1_with_pre_start_script/pre-start.stdout.log'))
    job_1_stderr = File.read(File.join(log_path, '/job_1_with_pre_start_script/pre-start.stderr.log'))

    expect(job_1_stdout).to include <<~OUTPUT.strip
      message on stdout of job 1 pre-start script
      template interpolation works in this script: this is pre_start_message_1
      message on stdout of job 1 new version pre-start script
    OUTPUT

    expect(job_1_stderr).to include <<~OUTPUT.strip
      message on stderr of job 1 pre-start script
      message on stderr of job 1 new version pre-start script
    OUTPUT
  end

  context 'when the pre-start scripts are corrupted' do
    let(:manifest) do
      Bosh::Spec::DeploymentManifestHelper.manifest_with_release.merge(
        'releases' => [{
          'name' => 'release_with_corrupted_pre_start',
          'version' => '1',
        }],
        'instance_groups' => [
          Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'job_with_templates_having_prestart_scripts',
            jobs: [
              {
                'name' => 'job_with_valid_pre_start_script',
                'release' => 'release_with_corrupted_pre_start',
              },
              {
                'name' => 'job_with_corrupted_pre_start_script',
                'release' => 'release_with_corrupted_pre_start',
              },
            ],
            instances: 1,
          ),
        ],
      )
    end

    it 'error out if run_script errors, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
      bosh_runner.run("upload-release #{asset_path('pre_start_script_releases/release_with_corrupted_pre_start-1.tgz')}")
      expect do
        deploy(manifest_hash: manifest)
      end.to raise_error(
        RuntimeError,
        Regexp.new(
          'result: 1 of 2 pre-start scripts failed. Failed Jobs: job_with_corrupted_pre_start_script. ' \
          'Successful Jobs: job_with_valid_pre_start_script.',
        ),
      )

      agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id
      log_path = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/"

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_with_valid_pre_start_script/bin/pre-start' script has successfully executed")
      expect(agent_log).to include("/jobs/job_with_corrupted_pre_start_script/bin/pre-start' script has failed with error")

      job_1_stdout = File.read(File.join(log_path, 'job_with_valid_pre_start_script/pre-start.stdout.log'))
      expect(job_1_stdout).to match('message on stdout of job_with_valid_pre_start_script pre-start script')

      job_corrupted_stdout = File.read(File.join(log_path, '/job_with_corrupted_pre_start_script/pre-start.stdout.log'))
      expect(job_corrupted_stdout).to match('message on stdout of job_with_corrupted_pre_start_script pre-start script')

      job_corrupted_stderr = File.read(File.join(log_path, '/job_with_corrupted_pre_start_script/pre-start.stderr.log'))
      expect(job_corrupted_stderr).not_to be_empty
    end
  end
end
