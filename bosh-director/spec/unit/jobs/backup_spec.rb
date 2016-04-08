require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe Jobs::Backup do
    describe 'DJ job class expectations' do
      let(:job_type) { :bosh_backup }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      include FakeFS::SpecHelpers

      let(:backup_file) { '/dest_dir/backup.tgz' }
      let(:tmp_output_dir) { File.join('/tmp/random') }
      let(:tar_gzipper) { instance_double('Bosh::Director::Core::TarGzipper') }
      let(:db_adapter) { double('db adapter') }

      subject(:backup_task) do
        Jobs::Backup.new(backup_file, tar_gzipper: tar_gzipper, db_adapter: db_adapter)
      end

      before do
        FileUtils.mkdir_p(tmp_output_dir)
        allow(Dir).to receive(:mktmpdir).and_yield(tmp_output_dir)
        allow(tar_gzipper).to receive(:compress)
        allow(db_adapter).to receive(:export)
      end

      it 'backs up the database' do
        expect(db_adapter).to receive(:export).with(File.join(tmp_output_dir, 'director_db.sql'))

        backup_task.perform
      end

      it 'combines the tarballs' do
        expect(tar_gzipper).to receive(:compress).with(tmp_output_dir, 'director_db.sql', backup_file)

        backup_task.perform
      end

      it 'returns the destination of the logs' do
        expect(backup_task.perform).to eq "Backup created at #{backup_file}"
      end
    end
  end
end
