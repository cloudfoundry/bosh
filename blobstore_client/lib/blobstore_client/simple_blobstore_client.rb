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
        raise "Could not create object, #{response.status}/#{response.content}" if response.status != 200
        response.content
      end

      def get(id)
        response = @client.get("#{@endpoint}/resources/#{id}", {}, @headers)
        raise "Could not fetch object, #{response.status}/#{response.content}" if response.status != 200
        response.content
      end

      def delete(id)
        response = @client.delete("#{@endpoint}/resources/#{id}", @headers)
        raise "Could not delete object, #{response.status}/#{response.content}" if response.status != 204
      end

    end
  end
end