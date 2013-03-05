module VCloudSdk
  module Connection

    class FileUploader
      class << self
        def upload(href, file, cookies = nil, http_method = :Put)
          request = create_request(href, file, cookies, http_method)
          net = create_connection(href)
          net.start do |http|
            response = http.request(request) {
              |http_response| http_response.read_body }
            raise ApiRequestError "Error Response: #{response.code}" if
              response.code.to_i >= 400
            response
          end
        end

        private

        def create_request(href, file, cookies = nil, http_method = :Put)
          headers = cookies ? {"Cookie" => cookies.map { |(key, val)|
            "#{key.to_s}=#{CGI::unescape(val)}" }.sort.join(";")} : {}
          # Ruby 1.8 does not have size on the file object
          headers["Content-Length"] = File.size(file.path).to_s
          headers["Transfer-Encoding"] = "chunked"
          request_type = Net::HTTP.const_get(http_method)
          request = request_type.new(href, headers)
          request.body_stream = file
          request
        end

        def create_connection(href)
          uri = URI::parse(href)
          net = Net::HTTP.new(uri.host, uri.port)
          net.use_ssl = uri.is_a?(URI::HTTPS)
          net.verify_mode = OpenSSL::SSL::VERIFY_NONE if net.use_ssl?
          net
        end
      end
    end

  end
end
