# Copyright (c) 2013 FamilySearch

module Bosh
  module Blobstore
    class CompositeBlobstoreClient < BaseClient

      def initialize(options)
        blobstores = options[:blobstores]

        if blobstores.nil?
          raise Bosh::Blobstore::BlobstoreError,
              'No blobstores were configured in options.'
        end

        @clients = blobstores.sort_by { |sym| sym.to_s }.map do |k, blobstore|
          provider = blobstore[:provider]

          if provider.nil?
            raise Bosh::Blobstore::BlobstoreError,
                'provider not specified for a child blobstore client.'
          end

          options = blobstore[:options]
          Client.create(provider, options)
        end

        if @clients.length < 2
          raise Bosh::Blobstore::BlobstoreError,
              'Less than two child blobstore clients were configured.'
        end
      end

      def create_file(file)
        @clients.first.create_file(file)
      end

      def get_file(id, file)
        @clients.each do |client|
          begin
            return client.get_file(id, file)
          rescue NotFound => e
            raise e if client.equal?(@clients.last)
          end
        end
      end

      def delete_object(oid)
        @clients.first.delete_object(oid)
      end
    end
  end
end
