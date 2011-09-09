module Bosh::Director

  class ResourceManager

    def get_resource(id)
      blobstore = Bosh::Director::Config.blobstore
      path = File.join(Dir.tmpdir, "resource-#{UUIDTools::UUID.random_create}")

      File.open(path, "w") do |f|
        blobstore.get(id, f)
      end

      path
    rescue Bosh::Blobstore::NotFound
      raise ResourceNotFound, id
    rescue Bosh::Blobstore::BlobstoreError => e
      raise ResourceError.new(id, e)
    end

  end

end
