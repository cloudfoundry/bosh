module Bosh::Director
  class BlobUtil
    # @param [String] path Path to a file to be uploaded
    # @return [String] Created blob id
    def self.create_blob(path)
      File.open(path) { |f| blobstore.create(f) }
    end

    def self.copy_blob(blobstore_id)
      # Create a copy of the given blob
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, 'w') do |file|
          blobstore.get(blobstore_id, file)
        end
        File.open(temp_path, 'r') do |file|
          blobstore_id = blobstore.create(file)
        end
      end
      blobstore_id
    end

    def self.delete_blob(blobstore_id)
      blobstore.delete(blobstore_id)
    end

    private

    def self.blobstore
      App.instance.blobstores.blobstore
    end


  end
end
