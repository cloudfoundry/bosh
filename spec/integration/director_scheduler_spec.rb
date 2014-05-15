require 'spec_helper'
require 'archive/tar/minitar'
require 'zlib'

describe 'director_scheduler', type: :integration do
  with_reset_sandbox_before_each

  def self.pending_for_travis_mysql!
    before do
      if ENV['TRAVIS'] && ENV['DB'] == 'mysql'
        pending 'Travis does not currently support mysqldump'
      end
    end
  end

  before do
    target_and_login
    runner = bosh_runner_in_work_dir(TEST_RELEASE_DIR)
    runner.run('reset release')
    runner.run('create release --force')
    runner.run('upload release')
    runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['persistent_disk'] = 20480
    deployment_manifest = yaml_file('simple', deployment_hash)
    runner.run("deployment #{deployment_manifest.path}")
    runner.run('deploy')
  end

  describe 'scheduled disk snapshots' do
    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    it 'snapshots a disk on a defined schedule' do
      waiter.wait(60) { expect(snapshots).to_not be_empty }

      keys = %w[deployment job index director_name director_uuid agent_id instance_id]
      snapshots.each do |snapshot|
        json = JSON.parse(File.read(snapshot))
        expect(json.keys - keys).to be_empty
      end
    end

    def snapshots
      Dir[File.join(current_sandbox.agent_tmp_path, 'snapshots', '*')]
    end
  end

  describe 'scheduled backups' do
    pending_for_travis_mysql!

    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    it 'backs up bosh on a defined schedule' do
      waiter.wait(60) { expect(backups).to_not be_empty }
    end

    def backups
      Dir[File.join(current_sandbox.sandbox_root, 'backup_destination', '*')]
    end
  end

  describe 'manual backup' do
    pending_for_travis_mysql!

    after { FileUtils.rm_f(tmp_dir) }
    let(:tmp_dir) { Dir.mktmpdir('manual-backup') }

    it 'backs up task logs, database and blobs' do
      runner = bosh_runner_in_work_dir(tmp_dir)
      expect(runner.run('backup backup.tgz')).to match(/Backup of BOSH director was put in/i)

      backup_file = Bosh::Spec::TarFileInspector.new("#{tmp_dir}/backup.tgz")
      expect(backup_file.file_names).to match_array(%w(task_logs.tgz director_db.sql blobs.tgz))
      expect(backup_file.smallest_file_size).to be > 0
    end
  end
end
