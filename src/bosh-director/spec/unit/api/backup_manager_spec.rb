require 'spec_helper'

module Bosh::Director
  describe Api::BackupManager do
    subject(:backup_manager) { described_class.new }

    describe '#create_bosh_backup' do
      before { allow(JobQueue).to receive(:new).with(no_args).and_return(job_queue) }
      let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

      before { allow(Config).to receive(:base_dir).and_return('fake-base-dir') }

      it 'enqueues a task to create a backup of BOSH' do
        task = instance_double('Bosh::Director::Models::Task')

        expect(job_queue).to receive(:enqueue).with(
          'username-1',
          Jobs::Backup,
          'bosh backup',
          ['fake-base-dir/backup.tgz'],
        ).and_return(task)

        expect(backup_manager.create_backup('username-1')).to eq(task)
      end
    end
  end
end
