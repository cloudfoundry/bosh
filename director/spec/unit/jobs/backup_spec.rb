require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

describe Bosh::Director::Jobs::Backup do
  describe 'Resque job class expectations' do
    let(:job_type) { :bosh_backup }
    it_behaves_like 'a Resque job'
  end

  describe '#perform' do
    include FakeFS::SpecHelpers

    let(:backup_file) { '/dest_dir/backup.tgz' }
    let(:tmp_output_dir) { File.join('/tmp/random') }
    let(:tar_gzipper) { double('tar gzipper') }
    let(:blobstore_client) { double(Bosh::Blobstore::Client) }
    let(:db_adapter) { double('db adapter') }
    let(:base_dir) { '/a/base/dir' }
    let(:log_dir) { '/logs/are/here' }

    subject(:backup_task) do
      Bosh::Director::Jobs::Backup.new(backup_file,
                                       tar_gzipper: tar_gzipper,
                                       blobstore: blobstore_client,
                                       db_adapter: db_adapter,
                                       base_dir: base_dir,
                                       log_dir: log_dir)
    end

    before do
      FileUtils.mkdir_p(tmp_output_dir)
      Dir.stub(:mktmpdir).and_yield(tmp_output_dir)

      tar_gzipper.stub(:compress)
      db_adapter.stub(:export)
      blobstore_client.stub(:list).and_return([])
    end

    it 'zips up the logs' do
      tar_gzipper.should_receive(:compress).with('/logs/are', ['here'], File.join(tmp_output_dir, 'logs.tgz'))

      backup_task.perform
    end

    it 'zips up the task logs' do
      tar_gzipper.should_receive(:compress).with('/a/base/dir', ['tasks'], File.join(tmp_output_dir, 'task_logs.tgz'))

      backup_task.perform
    end

    it 'backs up the database' do
      db_adapter.should_receive(:export).with(File.join(tmp_output_dir, 'director_db.sql'))

      backup_task.perform
    end

    it 'backs up the blobstore' do
      foo_file = double(File, path: 'foo')
      bar_file = double(File, path: 'bar')

      tmp_blobs_output_dir = tmp_output_dir

      File.stub(:open).with(File.join(tmp_blobs_output_dir, 'foo_blob_id'), 'w').and_yield(foo_file)
      File.stub(:open).with(File.join(tmp_blobs_output_dir, 'bar_blob_id'), 'w').and_yield(bar_file)

      Bosh::Director::Models::Package.make(name: 'foo', blobstore_id: 'foo_blob_id')
      Bosh::Director::Models::Package.make(name: 'bar', blobstore_id: 'bar_blob_id')

      blobstore_client.should_receive(:get).with('foo_blob_id', foo_file) # get *writes* the file
      blobstore_client.should_receive(:get).with('bar_blob_id', bar_file)

      tar_gzipper.should_receive(:compress).with(tmp_blobs_output_dir, %w[foo_blob_id bar_blob_id], File.join(tmp_output_dir, 'blobs.tgz'))

      backup_task.perform
    end

    it 'combines the tarballs' do
      tar_gzipper.should_receive(:compress).with(tmp_output_dir,
                                                 %w(logs.tgz task_logs.tgz director_db.sql blobs.tgz),
                                                 backup_file)
      backup_task.perform
    end

    it 'returns the destination of the logs' do
      expect(backup_task.perform).to eq "Backup created at #{backup_file}"
    end
  end
end
