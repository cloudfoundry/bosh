# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Api::ResourceManager do
    before(:each) do
      @blobstore_dir = File.join(Dir.tmpdir, 'blobstore')
      FileUtils.mkdir(@blobstore_dir)
    end

    after(:each) do
      FileUtils.rm_rf(@blobstore_dir)
    end

    let(:blobstore) { Bosh::Blobstore::Client.create('local', 'blobstore_path' => @blobstore_dir) }
    let(:manager) { Api::ResourceManager.new(blobstore) }

    it 'raises an error when trying to get non-existing resource' do
      expect {
        manager.get_resource('deadbeef')
      }.to raise_error(ResourceNotFound, "Resource `deadbeef' not found in the blobstore")
    end

    it 'raises an error when something went wrong with blobstore' do
      blobstore.stub(:get).and_raise(
        Bosh::Blobstore::BlobstoreError.new('bad stuff'))

      expect {
        manager.get_resource('deadbeef')
      }.to raise_error(ResourceError, "Blobstore error accessing resource `deadbeef': bad stuff")
    end

    it 'saves resource to a local file' do
      id = blobstore.create('some data')
      path = manager.get_resource_path(id)

      File.exists?(path).should be(true)
      File.read(path).should == 'some data'
    end

    it 'should return the contents of the blobstore id' do
      contents = 'some data'
      id = blobstore.create(contents)
      manager.get_resource(id).should == contents
    end

    it 'should delete a resource from the blobstore' do
      contents = 'some data'
      id = blobstore.create(contents)
      manager.delete_resource(id)
      expect {
        manager.get_resource(id)
      }.to raise_error Bosh::Director::ResourceNotFound
    end
  end
end
