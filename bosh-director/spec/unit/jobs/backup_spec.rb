require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe Jobs::Backup do
    describe 'Resque job class expectations' do
      let(:job_type) { :bosh_backup }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      include FakeFS::SpecHelpers

      let(:backup_file) { '/dest_dir/backup.tgz' }
      let(:tmp_output_dir) { File.join('/tmp/random') }
      let(:tar_gzipper) { instance_double('Bosh::Director::Core::TarGzipper') }
      let(:blobstore_client) { double(Bosh::Blobstore::Client) }
      let(:db_adapter) { double('db adapter') }
      let(:base_dir) { '/a/base/dir' }
      let(:log_dir) { '/logs/are/here' }

      subject(:backup_task) do
        Jobs::Backup.new(backup_file,
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
        tar_gzipper.should_receive(:compress).with('/logs/are', ['here'], File.join(tmp_output_dir, 'logs.tgz'), copy_first: true)

        backup_task.perform
      end

      it 'zips up the task logs' do
        tar_gzipper.should_receive(:compress).with('/a/base/dir', ['tasks'], File.join(tmp_output_dir, 'task_logs.tgz'), copy_first: true)

        backup_task.perform
      end

      it 'backs up the database' do
        db_adapter.should_receive(:export).with(File.join(tmp_output_dir, 'director_db.sql'))

        backup_task.perform
      end

      it 'backs up the blobstore' do
        foo_package_file = double(File, path: 'foo')
        bar_package_file = double(File, path: 'bar')
        foo_compiled_package_file = double(File, path: 'foo_compiled')
        bar_compiled_package_file = double(File, path: 'bar_compiled')
        foo_template_file = double(File, path: 'foo_template')
        bar_template_file = double(File, path: 'bar_template')

        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'foo_package_blob_id'), 'w').and_yield(foo_package_file)
        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'bar_package_blob_id'), 'w').and_yield(bar_package_file)
        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'foo_compiled_package_blob_id'), 'w').and_yield(foo_compiled_package_file)
        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'bar_compiled_package_blob_id'), 'w').and_yield(bar_compiled_package_file)
        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'foo_template_id'), 'w').and_yield(foo_template_file)
        File.stub(:open).with(File.join(tmp_output_dir, 'blobs', 'bar_template_id'), 'w').and_yield(bar_template_file)

        foo_pkg = Models::Package.make(name: 'foo_package', blobstore_id: 'foo_package_blob_id')
        bar_pkg = Models::Package.make(name: 'bar_package', blobstore_id: 'bar_package_blob_id')
        Models::CompiledPackage.make(package: foo_pkg, blobstore_id: 'foo_compiled_package_blob_id')
        Models::CompiledPackage.make(package: bar_pkg, blobstore_id: 'bar_compiled_package_blob_id')
        Models::Template.make(blobstore_id: 'foo_template_id')
        Models::Template.make(blobstore_id: 'bar_template_id')

        blobstore_client.should_receive(:get).with('foo_package_blob_id', foo_package_file) # get *writes* the file
        blobstore_client.should_receive(:get).with('bar_package_blob_id', bar_package_file)
        blobstore_client.should_receive(:get).with('foo_compiled_package_blob_id', foo_compiled_package_file)
        blobstore_client.should_receive(:get).with('bar_compiled_package_blob_id', bar_compiled_package_file)
        blobstore_client.should_receive(:get).with('foo_template_id', foo_template_file)
        blobstore_client.should_receive(:get).with('bar_template_id', bar_template_file)

        tar_gzipper.should_receive(:compress).with(tmp_output_dir, 'blobs', File.join(tmp_output_dir, 'blobs.tgz'))

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
end
