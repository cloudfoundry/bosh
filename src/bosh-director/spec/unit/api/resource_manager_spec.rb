require 'spec_helper'

module Bosh::Director
  describe Api::ResourceManager do
    let(:blobstore) { double('client') }
    let(:manager) { Api::ResourceManager.new(blobstore) }

    it 'raises an error when trying to get non-existing resource' do
      allow(blobstore).to receive(:get).and_raise(Bosh::Blobstore::NotFound)

      expect {
        manager.get_resource('deadbeef')
      }.to raise_error(ResourceNotFound, "Resource 'deadbeef' not found in the blobstore")
    end

    it 'raises an error when something went wrong with blobstore' do
      allow(blobstore).to receive(:get).and_raise(
        Bosh::Blobstore::BlobstoreError.new('bad stuff'))

      expect {
        manager.get_resource('deadbeef')
      }.to raise_error(ResourceError, "Blobstore error accessing resource 'deadbeef': bad stuff")
    end

    it 'saves resource to a local file' do
      blobstore.define_singleton_method(:get) {|id, f|
        if id == 99
          f.write('some data')
        end
      }
      path = manager.get_resource_path(99)

      expect(File.exist?(path)).to be(true)
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
      blobstore.define_singleton_method(:get) {|id|
        if id == 99
          'some data'
        end
      }

      expect(manager.get_resource(99)).to eq('some data')
    end

    it 'should delete a resource from the blobstore' do
      allow(blobstore).to receive(:delete).with(99)

      manager.delete_resource(99)
    end
  end
end
