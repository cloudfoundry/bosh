require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

describe Bosh::Director::Jobs::Backup do
  describe '.job_type' do
    it 'returns a symbol representing job type' do
      expect(Bosh::Director::Jobs::Backup.job_type).to eq(:bosh_backup)
    end
  end

  describe '#perform' do
    include FakeFS::SpecHelpers

    let(:backup_file) { '/dest_dir/backup.tgz' }
    let(:tmp_output_dir) { File.join('/tmp/random') }
    let(:tar_gzipper) { double('tar gzipper') }
    let(:blobstore_client) { double(Bosh::Blobstore::Client) }
    let(:db_adapter) { double('db adapter') }

    subject(:backup_task) do
      Bosh::Director::Jobs::Backup.new(backup_file,
                                       tar_gzipper: tar_gzipper,
                                       blobstore: blobstore_client,
                                       db_adapter: db_adapter)
    end

    before do
      FileUtils.mkdir_p(tmp_output_dir)
      Dir.stub(:mktmpdir).and_yield(tmp_output_dir)

      tar_gzipper.stub(:compress)
      db_adapter.stub(:export)
      blobstore_client.stub(:list).and_return([])
    end

    it 'zips up the logs' do
      tar_gzipper.should_receive(:compress).with('/', ['var/vcap/sys/log'], File.join(tmp_output_dir, 'logs.tgz'))

      backup_task.perform
    end

    it 'zips up the task logs' do
      tar_gzipper.should_receive(:compress).with('/', ['var/vcap/store/director/tasks'], File.join(tmp_output_dir, 'task_logs.tgz'))

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

      File.stub(:open).with(File.join(tmp_blobs_output_dir, 'foo'), 'w').and_yield(foo_file)
      File.stub(:open).with(File.join(tmp_blobs_output_dir, 'bar'), 'w').and_yield(bar_file)

      blobstore_client.stub(:list).and_return(%w[foo bar])
      blobstore_client.should_receive(:get).with('foo', foo_file) # get *writes* the file
      blobstore_client.should_receive(:get).with('bar', bar_file)

      tar_gzipper.should_receive(:compress).with(tmp_blobs_output_dir, %w[foo bar], File.join(tmp_output_dir, 'blobs.tgz'))

      backup_task.perform
    end

    context 'when the blobstore client does not support listing objects' do
      before do
        blobstore_client.stub(:list).and_raise(Bosh::Blobstore::NotImplemented)

      end

      it 'backup everything else' do
        expect {
          tar_gzipper.should_receive(:compress).exactly(3).times
          backup_task.perform
        }.not_to raise_error(Bosh::Blobstore::NotImplemented)
      end
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
