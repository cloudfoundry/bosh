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

    its(:package_name) { should eq 'test-package1' }
    its(:package_fingerprint) { should eq 'test-package-fingerprint' }
    its(:sha1) { should eq 'bbb84ce3e4aff2fd0ad5b7b5175e63f0ae64aa27' }
    its(:stemcell_sha1) { should eq 'test-stemcell-sha1' }
    its(:blobstore_id) { should eq 'test-blobstore-id' }
    its(:blob_path) { should eq asset('foobar.gz') }

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
