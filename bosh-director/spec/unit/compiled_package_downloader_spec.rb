require 'spec_helper'
require 'bosh/director/compiled_package_downloader'
require 'bosh/director/compiled_package_group'

module Bosh::Director
  describe CompiledPackageDownloader do
    subject(:downloader) { described_class.new(compiled_package_group, blobstore_client) }

    let(:compiled_package_group) do
      instance_double(
        'Bosh::Director::CompiledPackageGroup',
        compiled_packages: [compiled_package1, compiled_package2],
        stemcell_sha1: 'sha_1_for_stemcell',
      )
    end

    let(:blobstore_client) { double('blobstore client') }

    let(:compiled_package1) { instance_double('Bosh::Director::Models::CompiledPackage', blobstore_id: 'blobstore_id1') }
    let(:compiled_package2) { instance_double('Bosh::Director::Models::CompiledPackage', blobstore_id: 'blobstore_id2') }

    describe '#download' do
      before { blobstore_client.stub(:get) }

      after { downloader.cleanup }

      it 'returns download dir' do
        download_dir = downloader.download
        expect(download_dir).to be_a(String)
        expect(Dir.exists?(download_dir)).to be_true
      end

      it 'downloads blobs using blobstore client' do
        blobstore_client.should_receive(:get).with('blobstore_id1', be_a(File))
        blobstore_client.should_receive(:get).with('blobstore_id2', be_a(File))
        downloader.download
      end

      it 'creates blobs files under the blobs subdirectory' do
        download_dir = downloader.download
        expect(File.exist?(File.join(download_dir, 'compiled_packages', 'blobs', 'blobstore_id1'))).to be_true
        expect(File.exist?(File.join(download_dir, 'compiled_packages', 'blobs', 'blobstore_id2'))).to be_true
      end
    end

    describe '#cleanup' do
      before { blobstore_client.stub(:get) }

      # rm_f from FakeFS deletes directories unlike real rm_f;
      # hence, FakeFS is not being used in this spec
      it 'removes the download dir' do
        download_dir = downloader.download
        expect { downloader.cleanup }.to change {
          File.exists?(download_dir)
        }.from(true).to(false)
      end
    end
  end
end
