require 'spec_helper'

module Bosh::Director
  describe BlobUtil do
    let(:package_name) { 'package_name' }
    let(:package_fingerprint) { 'fingerprint' }
    let(:stemcell_sha1) { 'sha1' }
    let(:blob_id) { 'blob_id' }
    let(:stemcell) { instance_double('Bosh::Director::Models::Stemcell', sha1: stemcell_sha1) }
    let(:package) { instance_double('Bosh::Director::Models::Package', name: package_name, fingerprint: package_fingerprint) }
    let(:compiled_package) { instance_double('Bosh::Director::Models::CompiledPackage', package: package, stemcell: stemcell, blobstore_id: blob_id) }
    let(:dep_pkg2) { instance_double('Bosh::Director::Models::Package', fingerprint: 'dp_fingerprint2', version: '9.2-dev') }
    let(:dep_pkg1) { instance_double('Bosh::Director::Models::Package', fingerprint: 'dp_fingerprint1', version: '10.1-dev') }
    let(:compiled_package_cache_blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
    let(:cache_key) { 'cache_sha1' }
    let(:dep_key) { '[]' }

    before do
      allow(Config).to receive(:compiled_package_cache_blobstore).and_return(compiled_package_cache_blobstore)
    end

    describe 'save_to_global_cache' do
      it 'copies from the local blobstore to the compiled package cache' do
        fake_local_blobstore = instance_double('Bosh::Blobstore::LocalClient')
        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(fake_local_blobstore)

        expect(fake_local_blobstore).to receive(:get).with('blob_id', an_instance_of(File))
        expect(compiled_package_cache_blobstore).to receive(:create) do |file, cache_filename|
          expect(file.to_path).to match %r[/blob$]
          expect(cache_filename).to eq('package_name-cache_sha1')
        end

        BlobUtil.save_to_global_cache(compiled_package, cache_key)
      end
    end

    describe '.exists_in_global_cache?' do
      it 'returns true when the object exists' do
        expect(compiled_package_cache_blobstore).to receive(:exists?).with('package_name-cache_sha1').and_return(true)
        expect(BlobUtil.exists_in_global_cache?(package, cache_key)).to eq(true)
      end

      it 'returns false when the object does not exist' do
        expect(compiled_package_cache_blobstore).to receive(:exists?).with('package_name-cache_sha1').and_return(false)
        expect(BlobUtil.exists_in_global_cache?(package, cache_key)).to eq(false)
      end

    end

    describe 'fetch_from_global_cache' do
      it 'returns nil if compiled package not in global cache' do
        expect(compiled_package_cache_blobstore).to receive(:get).and_raise(Bosh::Blobstore::NotFound)

        expect(BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key)).to be_nil
      end

      it 'returns the compiled package model if the compiled package was in the global cache' do
        mock_compiled_package = instance_double('Bosh::Director::Models::CompiledPackage')
        expect(Models::CompiledPackage).to receive(:create) do |&block|
          cp = double
          expect(cp).to receive(:package=).with(package)
          expect(cp).to receive(:stemcell=).with(stemcell)
          expect(cp).to receive(:sha1=).with('cp sha1')
          expect(cp).to receive(:build=)
          expect(cp).to receive(:blobstore_id=).with(blob_id)
          expect(cp).to receive(:dependency_key=).with(dep_key)
          block.call(cp)
          mock_compiled_package
        end

        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(double('Bosh::Blobstore::Client', create: blob_id))

        allow(Digest::SHA1).to receive_message_chain(:file, :hexdigest).and_return('cp sha1')
        allow(Models::CompiledPackage).to receive(:generate_build_number)

        expect(compiled_package_cache_blobstore).to receive(:get) do |sha, file|
          expect(sha).to eq('package_name-cache_sha1')
          expect(file.to_path).to match %r[/blob$]
        end
        expect(BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key)).to eq(mock_compiled_package)
      end
    end
  end
end
