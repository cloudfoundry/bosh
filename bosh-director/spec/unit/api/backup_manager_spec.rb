require 'spec_helper'

describe Bosh::Director::Api::BackupManager do
  let(:user) { Bosh::Director::Models::User.make }
  let(:command_runner) { double('command_runner') }
  let(:backup_manager) { described_class.new }

  describe '#create_bosh_backup' do
    let(:task_id) { 42 }
    let(:task) { double('Task', id: task_id) }
    let(:user) { double('User') }

    before do
      Resque.stub(:enqueue)
      BD::JobQueue.any_instance.stub(:create_task => task)
    end

    it 'enqueues a task to create a backup of BOSH' do
      Resque.should_receive(:enqueue).with(BD::Jobs::Backup, task_id, '/var/vcap/store/director/backup.tgz')

      backup_manager.create_backup(user)
    end

    it 'returns the task so it can be tracked' do
      backup_manager.create_backup(user).should == task
    end
  end
end
