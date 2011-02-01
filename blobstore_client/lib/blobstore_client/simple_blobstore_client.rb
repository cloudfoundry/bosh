require "httpclient"

module Bosh
  module Blobstore
    class SimpleBlobstoreClient < BaseClient

      def initialize(options)
        @client = HTTPClient.new
        @endpoint = options["endpoint"]
        @headers = {}
        if options["user"] && options["password"]
          @headers["Authorization"] = "Basic " + Base64.encode64("#{options["user"]}:#{options["password"]}")
        end
      end

      def create_file(file)
        response = @client.post("#{@endpoint}/resources", {:content => file}, @headers)
        if response.status != 200
          raise BlobstoreError, "Could not create object, #{response.status}/#{response.content}"
        end
        response.content
      end

      def get_file(id, file)
        response = @client.get("#{@endpoint}/resources/#{id}", {}, @headers) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError, "Could not fetch object, #{response.status}/#{response.content}"
        end
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
