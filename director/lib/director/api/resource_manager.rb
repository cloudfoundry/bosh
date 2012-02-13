# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ResourceManager
      def get_resource(id)
        blobstore = Bosh::Director::Config.blobstore
        random_name = "resource-#{UUIDTools::UUID.random_create}"
        path = File.join(Dir.tmpdir, random_name)

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
end