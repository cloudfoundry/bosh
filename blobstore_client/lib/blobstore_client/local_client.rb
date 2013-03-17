# Copyright (c) 2009-2012 VMware, Inc.
require 'securerandom'

module Bosh
  module Blobstore
    class LocalClient < BaseClient
      CHUNK_SIZE = 1024*1024

      def initialize(options)
        super(options)
        @blobstore_path = @options[:blobstore_path]
        raise "No blobstore path given" if @blobstore_path.nil?
        FileUtils.mkdir_p(@blobstore_path) unless File.directory?(@blobstore_path)
      end

      protected

      def create_file(id, file)
        id ||= SecureRandom.uuid
        dst = object_file_path(id)
        raise BlobstoreError, "object id #{id} is already in use" if File.exist?(dst)
        File.open(dst, 'w') do |fh|
          until file.eof?
            fh.write(file.read(CHUNK_SIZE))
          end
        end
        id
      end

      def get_file(id, file)
        src = object_file_path(id)

        begin
          File.open(src, 'r') do |src_fh|
            until src_fh.eof?
              file.write(src_fh.read(CHUNK_SIZE))
            end
          end
        end
      rescue Errno::ENOENT
        raise NotFound, "Blobstore object '#{id}' not found"
      end

      def delete_object(id)
        file = object_file_path(id)
        FileUtils.rm(file)
      rescue Errno::ENOENT
        raise NotFound, "Blobstore object '#{id}' not found"
      end

      def object_exists?(oid)
        File.exists?(object_file_path(oid))
      end

      private

      def object_file_path(oid)
        File.join(@blobstore_path, oid)
      end

    end
  end
end
