require 'spec_helper'

describe Bosh::Director::BlobUtil do
  let(:package_name) { 'package_name'}
  let(:package_fingerprint) {'fingerprint'}
  let(:stemcell_sha1) {'sha1'}
  let(:blob_id) {'blob_id'}
  let(:stemcell) { mock("stemcell", sha1: stemcell_sha1)}
  let(:package) { mock("package", name: package_name, fingerprint: package_fingerprint)}
  let(:compiled_package) { mock("compiled_package", package: package, stemcell: stemcell, blobstore_id: blob_id)}
  let(:dep_pkg2) { mock("dependent package 2", fingerprint: "dp_fingerprint2", version: "9.2-dev")}
  let(:dep_pkg1) { mock("dependent package 1", fingerprint: "dp_fingerprint1", version: "10.1-dev")}
  let(:global_blobstore) { mock("global blobstore")}
  let(:cache_key) { "cache_sha1" }
  let(:dep_key) { "[]" }

  before(:each) do
    BD::Config.stub(:global_blobstore).and_return(global_blobstore)
  end

  describe '.save_to_global_cache' do
    it 'copies from the local blobstore to the global blobstore' do
      fake_local_blobstore = mock("local blobstore")
      BD::Config.should_receive(:blobstore).and_return(fake_local_blobstore)

      fake_local_blobstore.should_receive(:get).with('blob_id', an_instance_of(File))
      global_blobstore.should_receive(:create).with({
        key: 'package_name-cache_sha1',
        body: an_instance_of(File)
      })

      BD::BlobUtil.save_to_global_cache(compiled_package, cache_key)
    end
  end

  describe '.exists_in_global_cache?' do
    it 'returns true when the object exists' do
      global_blobstore.should_receive(:head).with('package_name-cache_sha1').and_return(Object.new)
      BD::BlobUtil.exists_in_global_cache?(package, cache_key).should == true
    end

    it 'returns false when the object does not exist' do
      global_blobstore.should_receive(:head).with('package_name-cache_sha1').and_return(nil)
      BD::BlobUtil.exists_in_global_cache?(package, cache_key).should == false
    end

  end

  describe '.fetch_from_global_cache' do
    it 'returns nil if compiled package not in global cache' do
      global_blobstore.should_receive(:get).with('package_name-cache_sha1').and_return(nil)
      BD::BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key).should be_nil
    end

    it 'returns the compiled package model if the compiled package was in the global cache' do
      mock_compiled_package = mock()
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

      BD::Config.should_receive(:blobstore).and_return(mock("local blobstore", create: blob_id))

      Digest::SHA1.stub_chain(:file, :hexdigest).and_return("cp sha1")
      BDM::CompiledPackage.stub(:generate_build_number)

      global_blobstore.should_receive(:get).with('package_name-cache_sha1').and_return(mock("blobstore file", body: "body of the file"))
      BD::BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dep_key).should == mock_compiled_package
    end
  end

end
