require 'spec_helper'
require 'bosh/director/compiled_package/compiled_package'

module Bosh::Director::CompiledPackage
  describe CompiledPackage do

    subject(:compiled_package) do
      described_class.new(
        package_name: 'test-package1',
        package_fingerprint: 'test-package-fingerprint',
        sha1: sha1,
        stemcell_sha1: 'test-stemcell-sha1',
        blobstore_id: 'test-blobstore-id',
        blob_path: asset("foobar.gz")
      )
    end

    let(:sha1) { 'bbb84ce3e4aff2fd0ad5b7b5175e63f0ae64aa27' }

    describe '#package_name' do
      subject { super().package_name }
      it { is_expected.to eq 'test-package1' }
    end

    describe '#package_fingerprint' do
      subject { super().package_fingerprint }
      it { is_expected.to eq 'test-package-fingerprint' }
    end

    describe '#sha1' do
      subject { super().sha1 }
      it { is_expected.to eq 'bbb84ce3e4aff2fd0ad5b7b5175e63f0ae64aa27' }
    end

    describe '#stemcell_sha1' do
      subject { super().stemcell_sha1 }
      it { is_expected.to eq 'test-stemcell-sha1' }
    end

    describe '#blobstore_id' do
      subject { super().blobstore_id }
      it { is_expected.to eq 'test-blobstore-id' }
    end

    describe '#blob_path' do
      subject { super().blob_path }
      it { is_expected.to eq asset('foobar.gz') }
    end

    describe '#check_blob_sha' do
      context 'SHA1 of blob_path does NOT match the SHA1 in compiled_package' do
        it 'does not raise a BlobShaMismatchError' do
          expect { compiled_package.check_blob_sha }.to_not raise_error
        end
      end

      context 'SHA1 of blob_path does NOT match the SHA1 in compiled_package' do
        let(:sha1) { 'totally-broken-SHA1' }

        it 'raises a BlobShaMismatchError' do
          expect {
            compiled_package.check_blob_sha
          }.to raise_error(BlobShaMismatchError, "Blob SHA mismatch in file #{compiled_package.blob_path}: expected: totally-broken-SHA1, got bbb84ce3e4aff2fd0ad5b7b5175e63f0ae64aa27")
        end
      end
    end
  end
end
