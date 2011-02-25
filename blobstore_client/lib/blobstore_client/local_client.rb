
module Bosh
  module Blobstore
    class LocalClient < BaseClient
      CHUNK_SIZE = 1024*1024

      def initialize(options)
        @blobstore_path = options['blobstore_path']
      end

      def create_file(file)
        raise BlobstoreError, "Not Implemented: Bosh::Blobstore::LocalClient is read only"
      end

      def get_file(id, file)
        src = File.join(@blobstore_path, id)

        begin
          File.open(src, 'r') do |src_fh|
            until src_fh.eof?
              file.write(src_fh.read(CHUNK_SIZE))
            end
          end
        end
      end

    end
  end
end
