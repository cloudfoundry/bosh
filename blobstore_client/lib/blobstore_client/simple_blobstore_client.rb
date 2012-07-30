# Copyright (c) 2009-2012 VMware, Inc.

require "httpclient"

module Bosh
  module Blobstore
    class SimpleBlobstoreClient < BaseClient

      def initialize(options)
        super(options)
        @client = HTTPClient.new
        @endpoint = @options[:endpoint]
        @bucket = @options[:bucket] || "resources"
        @headers = {}
        user = @options[:user]
        password = @options[:password]
        if user && password
          @headers["Authorization"] = "Basic " +
            Base64.encode64("#{user}:#{password}").strip
        end
      end

      def url(id=nil)
        ["#{@endpoint}/#{@bucket}", id].compact.join("/")
      end

      def create_file(file)
        response = @client.post(url, {:content => file}, @headers)
        if response.status != 200
          raise BlobstoreError,
            "Could not create object, #{response.status}/#{response.content}"
        end
        response.content
      end

      def get_file(id, file)
        response = @client.get(url(id), {}, @headers) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError,
            "Could not fetch object, #{response.status}/#{response.content}"
        end
      end

      def delete(id)
        response = @client.delete(url(id), @headers)
        if response.status != 204
          raise "Could not delete object, #{response.status}/#{response.content}"
        end
      end
    end
  end
end
