# Copyright (c) 2009-2012 VMware, Inc.

require 'fileutils'

module Bosh::Director
  module Api
    class ResourceManager

      def initialize(blobstore_client=App.instance.blobstores.blobstore)
        @logger = Config.logger
        @blobstore_client = blobstore_client
      end

      # Retrieves the resource `id` from the blobstore and stores it
      # locally, and returns the path to the file. It is the caller's
      # responsibility to delete the resulting file at some point.
      # An easy option is to call clean_old_tmpfiles before each call
      # to this method.
      #
      # @param [String] id
      # @return [String] path to the contents of the blobstore id
      def get_resource_path(id)
        blobstore_resource(id) do |blobstore|
          random_name = "resource-#{SecureRandom.uuid}"
          path = File.join(resource_tmpdir, random_name)

          File.open(path, "w") do |f|
            blobstore.get(id, f)
          end

          path
        end
      end

      # Returns the directory where files created by get_resource_path will be written.
      def resource_tmpdir
        Dir.tmpdir
      end

      # Deletes all get_resource_path temporary files that are more than 5 minutes old.
      def clean_old_tmpfiles
        Dir.glob("#{resource_tmpdir}/resource-*").
            select{|f| File.mtime(f) < (Time.now - (60*5)) }.
            each{|f| FileUtils.rm_f(f) }
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
        yield @blobstore_client
      rescue Bosh::Blobstore::NotFound
        raise ResourceNotFound, "Resource `#{id}' not found in the blobstore"
      rescue Bosh::Blobstore::BlobstoreError => e
        raise ResourceError, "Blobstore error accessing resource `#{id}': #{e}"
      end
    end
  end
end
