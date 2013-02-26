require 'spec_helper'

describe Bosh::Director::BlobUtil do
  let(:package_name) { 'package_name'}
  let(:package_fingerprint) {'fingerprint'}
  let(:stemcell_sha1) {'sha1'}
  let(:blob_id) {'blob_id'}


  describe '.save_to_global_cache' do
    it 'copies from the local blobstore to the global blobstore' do

      fake_global_blobstore = mock("global blobstore")
      fake_local_blobstore = mock("local blobstore")
      Bosh::Director::Config.should_receive(:blobstore).and_return(fake_local_blobstore)
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_local_blobstore.should_receive(:get).with('blob_id', an_instance_of(File))
      fake_global_blobstore.should_receive(:create).with({
        key: 'package_name-fingerprint-sha1',
        body: an_instance_of(File)
      })

      Bosh::Director::BlobUtil.save_to_global_cache(package_name, package_fingerprint, stemcell_sha1, blob_id)
    end
  end

  describe '.exists_in_global_cache?' do
    it 'returns true when the object exists' do
      fake_global_blobstore = mock("global blobstore")
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_global_blobstore.should_receive(:head).with('package_name-fingerprint-sha1').and_return(Object.new)

      Bosh::Director::BlobUtil.exists_in_global_cache?(package_name, package_fingerprint, stemcell_sha1).should == true
    end

    it 'returns false when the object does not exist' do
      fake_global_blobstore = mock("global blobstore")
      Bosh::Director::Config.should_receive(:global_blobstore).and_return(fake_global_blobstore)

      fake_global_blobstore.should_receive(:head).with('package_name-fingerprint-sha1').and_return(nil)

      Bosh::Director::BlobUtil.exists_in_global_cache?(package_name, package_fingerprint, stemcell_sha1).should == false
    end

  end
end
