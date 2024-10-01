require_relative '../spec_helper'

describe 'post-stop', type: :integration do
  with_reset_sandbox_before_each

  let(:release_path) { Dir.mktmpdir }
  let(:job_1_result) { true }
  let(:job_2_result) { true }
  let(:jobs) do
    [
      { 'name' => 'job-1', 'release' => 'post-stop', 'properties' => { 'succeed' => job_1_result } },
      { 'name' => 'job-2', 'release' => 'post-stop', 'properties' => { 'succeed' => job_2_result } },
    ]
  end
  let(:manifest) do
    Bosh::Spec::Deployments.simple_manifest_with_instance_groups(jobs: jobs).tap do |manifest|
      manifest.merge!(
        'releases' => [{
          'name' => 'post-stop',
          'version' => 'latest',
        }],
      )
    end
  end

  before do
    release_tarball = File.join(release_path, 'release.tgz')
    bosh_runner.run("reset-release --dir #{asset_path('post-stop')}")
    bosh_runner.run("create-release --dir #{asset_path('post-stop')} --tarball=#{release_tarball} --force")
    bosh_runner.run("upload-release #{release_tarball}")
    deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
  end

  after do
    FileUtils.rm_rf(release_path)
  end

  context 'when all jobs have successful post-stop scripts' do
    it 'stop command should exit 0 after running all scripts' do
      output = bosh_runner.run('stop foobar/0', deployment_name: 'simple')
      expect(output).to match(/Updating instance foobar: foobar.* \(0\)/)
      instance = director.instance('foobar', '0')
      expect(File.exist?(instance.file_path('job-1-success'))).to be_truthy
      expect(File.exist?(instance.file_path('job-2-success'))).to be_truthy
    end
  end

  context 'when at least one of the jobs have a failing post-stop scripts' do
    let(:job_1_result) { false }

    it 'runs scripts for all jobs but stop command fails' do
      expect do
        bosh_runner.run('stop foobar/0', deployment_name: 'simple')
      end.to raise_error(/Expected task '.*' to succeed but state is 'error'/)

      instance = director.instance('foobar', '0')
      expect(File.exist?(instance.file_path('job-1-fail'))).to be_truthy
      expect(File.exist?(instance.file_path('job-2-success'))).to be_truthy
    end
  end
end
