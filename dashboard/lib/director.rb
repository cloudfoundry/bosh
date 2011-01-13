require "restclient"
require "json"

module Bosh
  module Dashboard
    class Director

      DIRECTOR_HTTP_ERROR_CODES = [ 400, 403, 404, 500 ]
      API_TIMEOUT               = 86400 * 3
      OPEN_TIMEOUT              = 30

      attr_reader :director_uri

      def initialize(director_uri, user = nil, password = nil)
        if director_uri.nil? || director_uri =~ /^\s*$/
          raise DirectorMissing, "no director URI given"
        end
        
        @director_uri = director_uri
        @user         = user
        @password     = password
      end

      def exists?
        [401, 200].include?(get("/status")[0])
      end

      def authenticated?
        get("/status")[0] == 200
      end

      def list_stemcells
        get_json("/stemcells")
      end

      def list_releases
        get_json("/releases")
      end

      def list_deployments
        get_json("/deployments")
      end

      def list_running_tasks
        get_json("/running_tasks")
      end

      def list_recent_tasks(count = 30)
        get_json("/recent_tasks/#{count.to_i}")
      end

      [ :post, :put, :get, :delete ].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      def request(method, uri, content_type = nil, payload = nil, headers = {})
        headers = headers.dup
        headers["Content-Type"] = content_type if content_type

        req = {
          :method       => method,
          :url          => @director_uri + uri,
          :payload      => payload,
          :headers      => headers,
          :user         => @user,
          :password     => @password,
          :timeout      => API_TIMEOUT,
          :open_timeout => OPEN_TIMEOUT
        }

        status, body, response_headers = perform_http_request(req)
        
        if DIRECTOR_HTTP_ERROR_CODES.include?(status)
          raise DirectorError, parse_error_message(status, body)
        end

        [ status, body, response_headers ]

      rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
        raise DirectorInaccessible, "cannot access director (%s)" % [ e.message ]
      rescue SystemCallError => e
        raise DirectorError, "System call error while talking to director: #{e}"
      end

      private

      def perform_http_request(req)
        result = nil
        RestClient::Request.execute(req) do |response, request, result|
          result = [ response.code, response.body, response.headers ]
        end
        result
      rescue Net::HTTPBadResponse => e
        raise DirectorError, "Received bad HTTP response from director: #{e}"
      rescue RestClient::Exception => e
        raise DirectorError, "REST API call error: #{e}"
      end

      def get_json(url)
        status, body, headers = get(url, "application/json")
        JSON.parse(body)
      end

      def parse_error_message(status, body)
        parsed_body = JSON.parse(body.to_s)
        
        if parsed_body["code"] && parsed_body["description"]
          "Director error %s: %s" % [ parsed_body["code"], parsed_body["description"] ]
        else
          "Director error (HTTP %s): %s" % [ status, body ]
        end
      rescue JSON::ParserError
        "Director error (HTTP %s): %s" % [ status, body ]
      end
    end
  end
end
