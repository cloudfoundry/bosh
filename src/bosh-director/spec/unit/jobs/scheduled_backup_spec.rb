require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

describe Bosh::Director::Jobs::ScheduledBackup do
  include FakeFS::SpecHelpers

  let(:backup_job) { instance_double('Bosh::Director::Jobs::Backup', backup_file: 'backup_dest') }
  let(:backup_destination) { instance_double('Bosh::Blobstore::BaseClient', create: nil) }
  let(:task) { described_class.new(backup_job: backup_job, backup_destination: backup_destination) }

  before do
    allow(backup_job).to receive(:perform) { FileUtils.touch 'backup_dest' }
    allow(Time).to receive_messages(now: Time.parse('2013-07-02T09:55:40Z'))
  end

  describe 'DJ job class expectations' do
    let(:job_type) { :scheduled_backup }
    let(:queue) { :normal }
    it_behaves_like 'a DJ job'
  end

  describe 'perform' do
    it 'creates a backup' do
      expect(backup_job).to receive(:perform)
      task.perform
    end

    it 'pushes a backup to the destination blobstore' do
      expect(backup_destination).to receive(:create) do |backup_file, file_name|
        expect(backup_file.path).to eq 'backup_dest'
        expect(file_name).to eq 'backup-2013-07-02T09:55:40Z.tgz'
      end
      task.perform
    end

    it 'returns a string when successful' do
      expect(task.perform).to eq "Stored 'backup-2013-07-02T09:55:40Z.tgz' in backup blobstore"
    end
  end

  describe 'initialize' do
    let(:blobstores) { instance_double('Bosh::Director::Blobstores') }
    let(:backup_job_class) { class_double('Bosh::Director::Jobs::Backup').as_stubbed_const }
    let(:app_instance) { instance_double('Bosh::Director::App', blobstores: blobstores) }
    let!(:app_class) { class_double('Bosh::Director::App', instance: app_instance).as_stubbed_const }

    it 'injects defaults' do
      expect(backup_job_class).to receive(:new)

      expect(blobstores).to receive(:backup_destination)

      described_class.new
    end
  end
end
