require 'spec_helper'

describe Bosh::Spec::IntegrationTest::DirectorScheduler do
  include IntegrationExampleGroup

  before do
    target_and_login

    run_bosh('reset release', work_dir: TEST_RELEASE_DIR)
    run_bosh('create release --force', work_dir: TEST_RELEASE_DIR)
    run_bosh('upload release', work_dir: TEST_RELEASE_DIR)
    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['persistent_disk'] = 20480
    deployment_manifest = yaml_file('simple', deployment_hash)
    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh('deploy')
  end

  before { current_sandbox.scheduler_process.start }
  after { current_sandbox.scheduler_process.stop }

  def snapshots
    Dir[File.join(current_sandbox.agent_tmp_path, 'snapshots', '*')]
  end

  def backups
    Dir[File.join(current_sandbox.sandbox_root, 'backup_destination', '*')]
  end

  it 'snapshots a disk on a defined schedule' do
    30.times do
      break unless snapshots.empty?
      sleep 1
    end

    keys = %w[deployment job index director_name director_uuid agent_id instance_id]
    snapshots.each do |snapshot|
      json = JSON.parse(File.read(snapshot))
      expect(json.keys - keys).to be_empty
    end

    expect(snapshots).to_not be_empty
  end

  it 'backs up bosh on a defined schedule' do
    30.times do
      break unless backups.empty?
      sleep 1
    end

    expect(backups).to_not be_empty
  end
end
