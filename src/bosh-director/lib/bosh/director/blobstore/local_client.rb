module Bosh::Director
  module Blobstore
    class LocalClient < Client
      CHUNK_SIZE = 1024 * 1024

      def initialize(options)
        super(options)
        raise "No blobstore path given in options #{@options}" if @options[:blobstore_path].nil?
        @blobstore_path = URI(@options[:blobstore_path]).path
        FileUtils.mkdir_p(@blobstore_path) unless File.directory?(@blobstore_path)
      end

      protected

      def create_file(id, file)
        id ||= generate_object_id
        dst = object_file_path(id)
        raise BlobstoreError, "object id #{id} is already in use" if File.exist?(dst)
        File.open(dst, 'w') do |fh|
          fh.write(file.read(CHUNK_SIZE)) until file.eof?
        end
        id
      end

      def get_file(id, file)
        src = object_file_path(id)

        begin
          File.open(src, 'r') do |src_fh|
            file.write(src_fh.read(CHUNK_SIZE)) until src_fh.eof?
          end
        end
      rescue Errno::ENOENT
        raise NotFound, "Blobstore object '#{id}' not found"
      end

      def delete_object(id)
        file = object_file_path(id)
        FileUtils.rm(file)
      rescue Errno::ENOENT
        # ignore missing file error
      end

      def object_exists?(oid)
        File.exist?(object_file_path(oid))
      end

      def required_credential_properties_list
        []
      end

      private

      def object_file_path(oid)
        File.join(@blobstore_path, oid)
      end
    end
  end
end
