require "httpclient"

module Bosh
  module Blobstore
    class SimpleBlobstoreClient < Client

      def initialize(options)
        @client = HTTPClient.new
        @endpoint = options["endpoint"]
        @headers = {}
        if options["user"] && options["password"]
          @headers["Authorization"] = "Basic " + Base64.encode64("#{options["user"]}:#{options["password"]}")
        end
      end

      def create(contents)
        response = @client.post("#{@endpoint}/resources", {:content => contents}, @headers)
        if response.status != 200
          raise BlobstoreError, "Could not create object, #{response.status}/#{response.content}"
        end
        response.content
      end

      def get(id)
        response = @client.get("#{@endpoint}/resources/#{id}", {}, @headers)
        if response.status != 200
          raise BlobstoreError, "Could not fetch object, #{response.status}/#{response.content}"
        end
        response.content
      end

      def delete(id)
        response = @client.delete("#{@endpoint}/resources/#{id}", @headers)
        if response.status != 204
          raise "Could not delete object, #{response.status}/#{response.content}"
        end
      end
    end
  end
end
