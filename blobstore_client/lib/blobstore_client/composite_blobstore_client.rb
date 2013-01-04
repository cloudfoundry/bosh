# Copyright (c) 2013 FamilySearch

module Bosh
  module Blobstore
    class CompositeBlobstoreClient < Client

      def initialize(options)
        @clients = []
        options = Bosh::Common.symbolize_keys(options)
        blobstores = options[:blobstores]

        unless blobstores.nil?
          blobstores.each do |blobstore|
            blobstore = Bosh::Common.symbolize_keys(blobstore)
            provider = blobstore[:provider]
            options = blobstore[:options]
            @clients << Client.create(provider, options)
          end
        end

        raise Bosh::Blobstore::BlobstoreError, 'Less than two child blobstore clients were configured' if @clients.length < 2
      end

      def create(contents)
        @clients.first.create(contents)
      end

      def get(id, file = nil)
        @clients.each do |client|
          begin
            return client.get(id, file)
          rescue NotFound => e
            raise e if client.equal?(@clients.last)
          end
        end
      end

      def delete(id)
        @clients.first.delete(id)
      end

      def clients
        @clients
      end
    end
  end
end
