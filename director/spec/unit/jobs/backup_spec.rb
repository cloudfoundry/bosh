require 'spec_helper'
require 'blobstore_client'

describe Bosh::Director::Jobs::Backup do
  let(:dest_dir) { '/dest_dir' }
  let(:tar_gzipper) { double('tar gzipper') }
  let(:blobstore_client) { double(Bosh::Blobstore::Client) }
  let(:backup_task) { described_class.new(dest_dir, tar_gzipper, blobstore_client) }

  context '#backup_logs' do
    let(:log_directory) { '/var/vcap/sys/log' }

    it "zips up the logs" do
      tar_gzipper.should_receive(:compress).with(log_directory, '/foo/logs.tgz')
      expect(backup_task.backup_logs('/foo')).to eq('/foo/logs.tgz')
    end
  end

  context '#backup_task_logs' do
    let(:task_log_directory) { '/var/vcap/store/director/tasks' }

    it "zips up the task logs" do
      tar_gzipper.should_receive(:compress).with(task_log_directory, '/foo/task_logs.tgz')
      expect(backup_task.backup_task_logs('/foo')).to eq('/foo/task_logs.tgz')
    end
  end

  it 'backs up the database' do
    db_config = double('db_config')
    Bosh::Director::Config.stub(db_config: db_config)

    db_adapter = double('db adapter')
    db_adapter_creator = double('db adapter creator')
    backup_task.db_adapter_creator = db_adapter_creator
    db_adapter_creator.should_receive(:create).with(db_config).and_return(db_adapter)
    db_adapter.should_receive(:export).with('/foo/director_db.sql')

    expect(backup_task.backup_database('/foo')).to eq('/foo/director_db.sql')
  end

  context 'backing up the blobstore' do
    before do
      Dir.stub(:mkdir)
    end

    it 'backs up the blobstore' do
      fooFile = double(File)
      barFile = double(File)
      fooFile.stub(:path).and_return('foo')
      barFile.stub(:path).and_return('bar')
      File.should_receive(:open).with('/tmpdir/blobs/foo', 'w').and_yield(fooFile)
      File.should_receive(:open).with('/tmpdir/blobs/bar', 'w').and_yield(barFile)

      file_list = %w(foo bar)
      blobstore_client.should_receive(:list).and_return(file_list)
      blobstore_client.should_receive(:get).with('foo', fooFile)
      blobstore_client.should_receive(:get).with('bar', barFile)

      tar_gzipper.should_receive(:compress).with('/tmpdir/blobs', '/tmpdir/blobs.tgz')

      expect(backup_task.backup_blobstore('/tmpdir')).to eq('/tmpdir/blobs.tgz')
    end

    describe '#backup_blobstore' do
      it 'raises NotImplemented when the blobstore client does not support listing objects' do
        blobstore_client.should_receive(:list).and_raise(Bosh::Blobstore::NotImplemented)

        expect { backup_task.backup_blobstore('/foo') }.to raise_error(Bosh::Blobstore::NotImplemented)
      end
    end
  end

  context '#perform' do
    before do
      Dir.should_receive(:mktmpdir).with(nil, dest_dir).and_yield("#{dest_dir}/working_dir")
    end

    it 'skips backing up the blobstore when the blobstore client does not support listing objects' do
      backup_task.should_receive(:backup_logs).and_return('backup_logs')
      backup_task.should_receive(:backup_task_logs).and_return('backup_task_logs')
      backup_task.should_receive(:backup_database).and_return('backup_database')
      backup_task.should_receive(:backup_blobstore).and_raise(Bosh::Blobstore::NotImplemented)

      tar_gzipper.should_receive(:compress).with(%w(backup_logs backup_task_logs backup_database), "#{dest_dir}/backup.tgz")

      backup_task.perform
    end

    it 'combines the tarballs' do
      backup_task.should_receive(:backup_logs).and_return('backup_logs')
      backup_task.should_receive(:backup_task_logs).and_return('backup_task_logs')
      backup_task.should_receive(:backup_database).and_return('backup_database')
      backup_task.should_receive(:backup_blobstore).and_return('backup_blobstore')

      tar_gzipper.should_receive(:compress).with(%w(backup_logs backup_task_logs backup_database backup_blobstore), "#{dest_dir}/backup.tgz")

      backup_task.perform
    end

    it 'returns the destination of the logs' do
      backup_task.stub(:backup_logs)
      backup_task.stub(:backup_task_logs)
      backup_task.stub(:backup_database)
      backup_task.stub(:backup_blobstore)
      tar_gzipper.stub(:compress)

      expect(backup_task.perform).to eq "Backup created at #{dest_dir}/backup.tgz"
    end
  end
end