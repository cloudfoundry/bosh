# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ResourceManager

      def initialize
        @logger = Config.logger
      end

      # Retrieves the resource `id` from the blobstore and stores it
      # locally, and returns the path to the file
      #
      # @param [String] id
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

      # Retrieves the resource `id` from the blobstore and returns the
      # contents of it.
      # @param [String] id
      # @return [String] contents of the blobstore id
      def get_resource(id)
        @logger.debug("Downloading #{id} from blobstore...")

        blob = nil
        blobstore_resource(id) do |blobstore|
          blob = blobstore.get(id)
        end

        @logger.debug("Downloaded #{id} from blobstore")
        blob
      end

      # Deletes the resource `id` from the blobstore
      # @param [String] id
      def delete_resource(id)
        @logger.debug("Deleting #{id} from blobstore...")

        blobstore_resource(id) do |blobstore|
          blobstore.delete(id)
        end

        @logger.debug("Deleted #{id} from blobstore")
      end

      private

      def blobstore_resource(id)
        blobstore = Bosh::Director::Config.blobstore
        yield blobstore
      rescue Bosh::Blobstore::NotFound
        raise ResourceNotFound, "Resource `#{id}' not found in the blobstore"
      rescue Bosh::Blobstore::BlobstoreError => e
        raise ResourceError, "Blobstore error accessing resource `#{id}': #{e}"
      end
    end
  end
end