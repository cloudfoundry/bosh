require 'base64'
require 'httpclient'

module Bosh
  module Blobstore
    class SimpleBlobstoreClient < BaseClient

      def initialize(options)
        super(options)

        @client = HTTPClient.new
        @endpoint = @options[:endpoint]
        @bucket = @options[:bucket] || 'resources'
        @headers = {}

        user = @options[:user]
        password = @options[:password]

        if user && password
          @headers['Authorization'] = 'Basic ' +
            Base64.strict_encode64("#{user}:#{password}").strip
        end
      end

      def url(id = nil)
        ["#{@endpoint}/#{@bucket}", id].compact.join('/')
      end

      def create_file(id, file)
        response = @client.post(url(id), { content: file }, @headers)
        if response.status != 200
          raise BlobstoreError,
                "Could not create object, #{response.status}/#{response.content}"
        end
        response.content
      end

      def get_file(id, file)
        response = @client.get(url(id), header: @headers) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError,
                "Could not fetch object, #{response.status}/#{response.content}"
        end
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
