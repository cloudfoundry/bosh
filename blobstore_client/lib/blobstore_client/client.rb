# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Blobstore
    class Client
      PROVIDER_NAMES = %w[dav simple s3 swift atmos local]

      def self.create(blobstore_provider, options = {})
        unless PROVIDER_NAMES.include? blobstore_provider
          raise BlobstoreError, "Invalid client provider, available providers are: #{PROVIDER_NAMES}"
        end

        blobstore_client_constantize(blobstore_provider).new(options)
      end

      private

      def self.blobstore_client_constantize(base_string)
        class_string = base_string.capitalize + (base_string == 'local' ? '' : 'Blobstore') + 'Client'
        Bosh::Blobstore.const_get class_string
      end
    end
  end
end
