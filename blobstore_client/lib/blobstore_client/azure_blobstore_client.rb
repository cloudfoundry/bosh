# Copyright (c) 2013 Uhuru Software, Inc.

require 'azure'

module Bosh
  module Blobstore
    class AzureBlobstoreClient < BaseClient

      CHUNK_SIZE = 1024 * 1024
      DEFAULT_ENDPOINT = 'http://%s.blob.core.windows.net'

      # Blobstore client for Azure Block Blobs
      def initialize(options)
        super(options)

        @storage_account_name = @options[:storage_account_name]
        @container_name = @options[:container_name]

        raise BlobstoreError, 'storage_account_name required' unless @storage_account_name
        raise BlobstoreError, 'container_name required' unless @container_name

        @storage_access_key = @options[:storage_access_key]
        @storage_blob_host = @options[:storage_blob_host]

        if read_only?
          @options[:bucket] = @options[:container_name]
          @options[:endpoint] = endpoint
          @simple = SimpleBlobstoreClient.new(@options)
        else
          Azure.config.storage_account_name = @storage_account_name
          Azure.config.storage_access_key = @storage_access_key if @storage_access_key
          Azure.config.storage_blob_host = @storage_blob_host if @storage_blob_host

          @azure_blob_client = Azure::BlobService.new
        end
      end

      protected

      # Create a Azure block blob from a file
      def create_file(object_id, file)
        raise BlobstoreError, 'unsupported action for read-only access' if @simple

        object_id ||= generate_object_id

        raise BlobstoreError, "object id #{object_id} is already in use" if object_exists?(object_id)

        blocks = []
        block_index = 0

        until file.eof?
          chunk = file.read(CHUNK_SIZE)

          # "...all block IDs must be the same length." http://msdn.microsoft.com/en-us/library/windowsazure/dd135726.aspx
          block_id = sprintf '%010d', block_index

          @azure_blob_client.create_blob_block(@container_name, object_id, block_id, chunk)
          blocks << [block_id, :uncommited]

          block_index += 1
        end

        # Create the blob from the previous uploaded chunked blocks
        @azure_blob_client.commit_blob_blocks(@container_name, object_id, blocks)

        object_id
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to create object '#{object_id}': #{e.inspect}"
      end

      # Download an Azure block blob to a file
      def get_file(object_id, file)
        return @simple.get_file(object_id, file) if @simple

        begin
          blob = @azure_blob_client.get_blob_properties(@container_name, object_id)
          total_len = blob.properties[:content_length]
          cur_len = 0

          while cur_len < total_len
            blob, content = @azure_blob_client.get_blob(
              @container_name,
              object_id,
              { start_range: cur_len, end_range: (cur_len + CHUNK_SIZE - 1) })
            cur_len += content.length
            file.write(content)
          end
        rescue Azure::Core::Error => e
          raise BlobstoreError, "Failed to get object '#{object_id}': #{e.inspect}"
        end
      end

      # Delete an Azure block blob
      def delete_object(object_id)
        raise BlobstoreError, 'unsupported action for read-only access' if @simple

        begin
          @azure_blob_client.delete_blob(@container_name, object_id)
        rescue Azure::Core::Error => e
          raise BlobstoreError, "Failed to delete object '#{object_id}: #{e.message}'"
        end
      end

      # Check if the Azure block blob exists
      def object_exists?(object_id)
        return @simple.exists?(object_id) if @simple

        begin
          @azure_blob_client.get_blob_properties(@container_name, object_id)
          true
        rescue Azure::Core::Error
          false
        end
      end

      protected

      def read_only?
        @options[:storage_access_key].nil?
      end

      def endpoint
        if @storage_blob_host.nil?
          DEFAULT_ENDPOINT % @storage_account_name
        else
          @storage_blob_host
        end
      end

    end
  end
end
