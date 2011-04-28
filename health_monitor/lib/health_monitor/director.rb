module Bosh::HealthMonitor
  class Director

    def initialize(options)
      @endpoint = options["endpoint"].to_s
      @user     = options["user"].to_s
      @password = options["password"].to_s
    end

    def get_deployments
      http = perform_request(:get, "/deployments")

      body   = http.response
      status = http.response_header.http_status

      if status != "200"
        raise DirectorError, "Cannot get deployments from director: #{status} #{body}"
      end

      parse_json(body, Array)
    end

    def get_deployment(name)
      http = perform_request(:get, "/deployments/#{name}")

      body   = http.response
      status = http.response_header.http_status

      if status != "200"
        raise DirectorError, "Cannot get deployment `#{name}' from director: #{status} #{body}"
      end

      parse_json(body, Hash)
    end

    private

    def parse_json(json, expected_type = nil)
      result = Yajl::Parser.parse(json)

      if expected_type && !result.kind_of?(expected_type)
        raise DirectorError, "Invalid JSON response format, expected #{expected_type}, got #{result.class}"
      end

      result

    rescue Yajl::ParseError => e
      raise DirectorError, "Cannot parse director response: #{e.message}"
    end

    def perform_request(method, uri)
      f = Fiber.current

      headers = {
        "authorization" => [@user, @password]
      }

      http = EM::HttpRequest.new(@endpoint + uri).send(method.to_sym, :head => headers)

      http.callback { f.resume(http) }
      http.errback  { f.resume(http) }

      Fiber.yield
    end

  end
end
