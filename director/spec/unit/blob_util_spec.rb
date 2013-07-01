require 'spec_helper'

describe Bosh::Director::BlobUtil do
  let(:package_name) { 'package_name'}
  let(:package_fingerprint) {'fingerprint'}
  let(:stemcell_sha1) {'sha1'}
  let(:blob_id) {'blob_id'}
  let(:stemcell) { mock(BDM::Stemcell, sha1: stemcell_sha1) }
  let(:package) { mock(BDM::Package, name: package_name, fingerprint: package_fingerprint) }
  let(:compiled_package) { mock(BDM::CompiledPackage, package: package, stemcell: stemcell, blobstore_id: blob_id) }
  let(:dep_pkg2) { mock(BDM::Package, fingerprint: "dp_fingerprint2", version: "9.2-dev") }
  let(:dep_pkg1) { mock(BDM::Package, fingerprint: "dp_fingerprint1", version: "10.1-dev") }
  let(:compiled_package_cache_blobstore) { mock(Bosh::Blobstore::BaseClient) }
  let(:cache_key) { "cache_sha1" }
  let(:dep_key) { "[]" }

  before(:each) do
    BD::Config.stub(:compiled_package_cache_blobstore).and_return(compiled_package_cache_blobstore)
  end

  describe 'save_to_global_cache' do
    it 'copies from the local blobstore to the compiled package cache' do
      fake_local_blobstore = mock(Bosh::Blobstore::LocalClient)
      BD::App.stub_chain(:instance, :blobstores, :blobstore).and_return(fake_local_blobstore)

      fake_local_blobstore.should_receive(:get).with('blob_id', an_instance_of(File))
      compiled_package_cache_blobstore.should_receive(:create) do |file, cache_filename|
        file.to_path.should match %r[/blob$]
        cache_filename.should == 'package_name-cache_sha1'
      end

      BD::BlobUtil.save_to_global_cache(compiled_package, cache_key)
    end
  end

  describe '.exists_in_global_cache?' do
    it 'returns true when the object exists' do
      compiled_package_cache_blobstore.should_receive(:exists?).with('package_name-cache_sha1').and_return(true)
      BD::BlobUtil.exists_in_global_cache?(package, cache_key).should == true
    end

    it 'returns false when the object does not exist' do
      compiled_package_cache_blobstore.should_receive(:exists?).with('package_name-cache_sha1').and_return(false)
      BD::BlobUtil.exists_in_global_cache?(package, cache_key).should == false
    end

  end

  describe 'fetch_from_global_cache' do
    it 'returns nil if compiled package not in global cache' do
      compiled_package_cache_blobstore.should_receive(:get).and_raise(Bosh::Blobstore::NotFound)

      BD::BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key).should be_nil
    end

    it 'returns the compiled package model if the compiled package was in the global cache' do
      mock_compiled_package = mock(BDM::CompiledPackage)
      BDM::CompiledPackage.should_receive(:create) do |&block|
        cp = mock()
        cp.should_receive(:package=).with(package)
        cp.should_receive(:stemcell=).with(stemcell)
        cp.should_receive(:sha1=).with("cp sha1")
        cp.should_receive(:build=)
        cp.should_receive(:blobstore_id=).with(blob_id)
        cp.should_receive(:dependency_key=).with(dep_key)
        block.call(cp)
        mock_compiled_package
      end

      BD::App.stub_chain(:instance, :blobstores, :blobstore).and_return(mock(Bosh::Blobstore::Client, create: blob_id))

      Digest::SHA1.stub_chain(:file, :hexdigest).and_return("cp sha1")
      BDM::CompiledPackage.stub(:generate_build_number)

      compiled_package_cache_blobstore.should_receive(:get) do |sha, file|
        sha.should == 'package_name-cache_sha1'
        file.to_path.should match %r[/blob$]
      end
      BD::BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key).should == mock_compiled_package
    end
  end

end
