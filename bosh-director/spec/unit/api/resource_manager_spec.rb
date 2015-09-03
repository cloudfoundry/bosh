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
      allow(blobstore).to receive(:get).and_raise(
        Bosh::Blobstore::BlobstoreError.new('bad stuff'))

      expect {
        manager.get_resource('deadbeef')
      }.to raise_error(ResourceError, "Blobstore error accessing resource `deadbeef': bad stuff")
    end

    it 'saves resource to a local file' do
      id = blobstore.create('some data')
      path = manager.get_resource_path(id)

      expect(File.exists?(path)).to be(true)
      expect(File.read(path)).to eq('some data')
    end

    it 'deletes temp blobstore resources older than 5 mintues' do
      five_minutes_old = File.join(manager.resource_tmpdir, 'resource-ten_minutes_old')
      one_minute_old = File.join(manager.resource_tmpdir, 'resource-one_minute_old')

      FileUtils.touch([five_minutes_old], mtime: Time.now - 301)
      FileUtils.touch([one_minute_old], mtime: Time.now - 60)

      manager.clean_old_tmpfiles

      expect(File.exist?(five_minutes_old)).to eq false
      expect(File.exist?(one_minute_old)).to eq true
    end

    it 'should return the contents of the blobstore id' do
      contents = 'some data'
      id = blobstore.create(contents)
      expect(manager.get_resource(id)).to eq(contents)
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
