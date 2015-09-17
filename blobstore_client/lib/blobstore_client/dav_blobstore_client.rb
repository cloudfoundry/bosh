# Copyright (c) 2009-2012 VMware, Inc.

require 'base64'
require 'httpclient'
require 'digest/sha1'

module Bosh
  module Blobstore
    class DavBlobstoreClient < BaseClient

      def initialize(options)
        super(options)
        @client = HTTPClient.new

        if @options[:ssl_no_verify]
          @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
          @client.ssl_config.verify_callback = proc {}
        end

        @endpoint = @options[:endpoint]
        @headers = {}
        user = @options[:user]
        password = @options[:password]
        if user && password
          @headers['Authorization'] = 'Basic ' +
            Base64.strict_encode64("#{user}:#{password}").strip
        end
      end

      def url(id)
        prefix = Digest::SHA1.hexdigest(id)[0, 2]

        [@endpoint, prefix, id].compact.join('/')
      end

      def create_file(id, file)
        id ||= generate_object_id

        response = @client.put(url(id), file, @headers)

        raise BlobstoreError, "Could not create object, #{response.status}/#{response.content}" if response.status != 201

        id
      end

      def get_file(id, file)
        response = @client.get(url(id), {}, @headers) do |block|
          file.write(block)
        end

        raise BlobstoreError, "Could not fetch object, #{response.status}/#{response.content}" if response.status != 200
      end

      def delete_object(id)
        response = @client.delete(url(id), header: @headers)

        raise NotFound, "Object '#{id}' is not found, #{response.status}/#{response.content}" if response.status == 404
        raise BlobstoreError, "Could not delete object, #{response.status}/#{response.content}" if response.status != 204
      end

      def object_exists?(id)
        response = @client.head(url(id), header: @headers)
        if response.status == 200
          true
        elsif response.status == 404
          false
        else
          raise BlobstoreError, "Could not get object existence, #{response.status}/#{response.content}"
        end
      end
    end
  end
end
