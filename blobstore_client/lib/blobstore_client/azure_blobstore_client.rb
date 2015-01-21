require 'azure'

module Bosh
  module Blobstore
    class AzureBlobstoreClient < BaseClient

      attr_reader :container_name

      # Blobstore client for Azure blob storage
      # @param [Hash] options Azure BlobStore options
      # @option options [Symbol] container_name
      # @option options [Symbol] storage_account_name
      # @option options [Symbol] storage_access_key
      def initialize(options)
        super(options)
        @container_name = @options[:container_name]

        Azure.configure do |config|
          config.storage_account_name = @options[:storage_account_name]
          config.storage_access_key = @options[:storage_access_key]
        end

        @azure_blob_service = Azure::BlobService.new

        begin
          container = @azure_blob_service.get_container_properties(container_name)
        rescue Azure::Core::Error => e
          # container does not exist
          @azure_blob_service.create_container(container_name)
        end
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to initialize Azure blobstore: #{e.description}"
      end

      def create_file(id, file)
        id ||= generate_object_id

        raise BlobstoreError, "object id #{id} is already in use" if object_exists?(id)

        content = file.read
        @azure_blob_service.create_block_blob(container_name, id, content)

        id
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to create object, Azure response error: #{e.description}"
      end

      def get_file(id, file)
        blob, content = @azure_blob_service.get_blob(container_name, id)
        file.write(content)

      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to find object '#{id}', Azure response error: #{e.description}"
      end

      def delete_object(id)
        @azure_blob_service.delete_blob(container_name, id)

      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to delete object '#{id}', Azure response error: #{e.description}"
      end

      def object_exists?(id)
        result = @azure_blob_service.get_blob_properties(container_name, id)
        true

      rescue Azure::Core::Error => e
        false
      end

    end
  end
end
