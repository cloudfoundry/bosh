# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ResourceManager

      # Retrives the resource `id` from the blobstore and stores it
      # locally, and returns the path to the file
      #
      # @param [String] blobstore id
      # @return [String] path to the contents of the blobstore id
      def get_resource_path(id)
        blobstore_resource(id) do |blobstore|
          random_name = "resource-#{UUIDTools::UUID.random_create}"
          path = File.join(Dir.tmpdir, random_name)

          File.open(path, "w") do |f|
            blobstore.get(id, f)
          end

          path
        end
      end

      # Retrives the resource `id` from the blobstore and returns the
      # contents of it
      #
      # @param [String] blobstore id
      # @return [String] contents of the blobstore id
      def get_resource(id)
        blobstore_resource(id) do |blobstore|
          blobstore.get(id)
        end
      end

      # Deletes the resource `id` from the blobstore
      #
      # @param [String] blobstore id
      def delete_resource(id)
        blobstore_resource(id) do |blobstore|
          blobstore.delete(id)
        end
      end

      private

      def blobstore_resource(id)
        blobstore = Bosh::Director::Config.blobstore
        yield blobstore
      rescue Bosh::Blobstore::NotFound
        raise ResourceNotFound, id
      rescue Bosh::Blobstore::BlobstoreError => e
        raise ResourceError.new(id, e)
      end
    end
  end
end