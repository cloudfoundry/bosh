require 'spec_helper'

describe 'errand jobs', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest) do
    Bosh::Spec::NewDeployments.manifest_with_release.merge(
      'instance_groups' => [
        Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
          name: 'job_with_post_deploy_script',
          jobs: [
            {
              'name' => 'job_1_with_post_deploy_script',
              'release' => 'bosh-release',
            },
            {
              'name' => 'job_2_with_post_deploy_script',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        ),
        Bosh::Spec::NewDeployments.simple_errand_instance_group.merge(
          'name' => 'alive-errand',
        ),
        Bosh::Spec::NewDeployments.simple_errand_instance_group.merge(
          'name' => 'dead-errand',
        ),
      ],
    )
  end

  before do
    prepare_for_deploy
    deploy_simple_manifest(manifest_hash: manifest)
  end

  context 'when errand has been run with --keep-alive' do
    it 'immediately updates the errand job' do
      bosh_runner.run('manifest -d simple')

      bosh_runner.run('run-errand -d simple alive-errand --keep-alive')

      job_with_post_deploy_script_instance = director.instance('job_with_post_deploy_script', '0')
      expect(File.exist?(job_with_post_deploy_script_instance.file_path('jobs/foobar/monit'))).to be_falsey

      job_with_errand_instance = director.instance('alive-errand', '0')
      expect(File.exist?(job_with_errand_instance.file_path('jobs/errand1/bin/run'))).to be_truthy
      expect(File.exist?(job_with_errand_instance.file_path('jobs/foobar/monit'))).to be_falsey

      new_manifest = manifest
      new_manifest['instance_groups'][0]['jobs'] << { 'name' => 'foobar', 'release' => 'bosh-release' }
      new_manifest['instance_groups'][1]['jobs'] << { 'name' => 'foobar', 'release' => 'bosh-release' }
      new_manifest['instance_groups'][2]['jobs'] << { 'name' => 'foobar', 'release' => 'bosh-release' }
      deploy_simple_manifest(manifest_hash: new_manifest)

      job_with_post_deploy_script_instance = director.instance('job_with_post_deploy_script', '0')
      expect(File.exist?(job_with_post_deploy_script_instance.file_path('jobs/foobar/monit'))).to be_truthy

      job_with_errand_instance = director.instance('alive-errand', '0')
      expect(File.exist?(job_with_errand_instance.file_path('jobs/foobar/monit'))).to be_truthy
    end
  end
end
