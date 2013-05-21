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
        @endpoint = @options[:endpoint]
        #@bucket = @options[:bucket] || "resources" # dav (or simple) doesn't support buckets
        @headers = {}
        user = @options[:user]
        password = @options[:password]
        if user && password
          @headers["Authorization"] = "Basic " +
              Base64.encode64("#{user}:#{password}").strip
        end
      end

      def url(id)
        prefix = Digest::SHA1.hexdigest(id)[0, 2]

        [@endpoint, prefix, id].compact.join('/')
      end

      def create_file(id, file)
        id ||= generate_object_id

        response = @client.put(url(id), file, @headers)
        if response.status != 201
          raise BlobstoreError, "Could not create object, #{response.status}/#{response.content}"
        end

        id
      end

      def get_file(id, file)
        response = @client.get(url(id), {}, @headers) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError, "Could not fetch object, #{response.status}/#{response.content}"
        end
      end

      def delete_object(id)
        response = @client.delete(url(id), @headers)
        if response.status != 204
          raise BlobstoreError, "Could not delete object, #{response.status}/#{response.content}"
        end
      end

      def object_exists?(id)
        response = @client.head(url(id), :header => @headers)
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
