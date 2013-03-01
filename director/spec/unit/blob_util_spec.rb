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

  describe '.save_to_global_cache' do
    it 'copies from the local blobstore to the global blobstore' do
      fake_global_blobstore = mock("global blobstore")
      fake_local_blobstore = mock("local blobstore")
      Bosh::Director::Config.should_receive(:blobstore).and_return(fake_local_blobstore)
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_local_blobstore.should_receive(:get).with('blob_id', an_instance_of(File))
      fake_global_blobstore.should_receive(:create).with({
        key: 'package_name-cache_sha1',
        body: an_instance_of(File)
      })

      Bosh::Director::BlobUtil.save_to_global_cache(compiled_package, "cache_sha1")
    end
  end

  describe '.exists_in_global_cache?' do
    it 'returns true when the object exists' do
      fake_global_blobstore = mock("global blobstore")
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_global_blobstore.should_receive(:head).with('package_name-cache_sha1').and_return(Object.new)

      Bosh::Director::BlobUtil.exists_in_global_cache?(package, "cache_sha1").should == true
    end

    it 'returns false when the object does not exist' do
      fake_global_blobstore = mock("global blobstore")
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_global_blobstore.should_receive(:head).with('package_name-cache_sha1').and_return(nil)

      Bosh::Director::BlobUtil.exists_in_global_cache?(package, "cache_sha1").should == false
    end

  end
end
