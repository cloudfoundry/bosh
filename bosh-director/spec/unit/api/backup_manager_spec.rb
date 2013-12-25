require 'spec_helper'

module Bosh::Director
  describe Api::BackupManager do
    let(:username) { 'username-1' }
    let(:backup_manager) { described_class.new }

    describe '#create_bosh_backup' do
      let(:task) { double('fake task') }
      let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

      before do
        JobQueue.stub(:new).and_return(job_queue)
      end

      it 'enqueues a task to create a backup of BOSH' do
        job_queue.should_receive(:enqueue).with(
          username, Jobs::Backup, 'bosh backup', ['/var/vcap/store/director/backup.tgz']).and_return(task)

        expect(backup_manager.create_backup(username)).to eq(task)
      end
    end
  end
end
