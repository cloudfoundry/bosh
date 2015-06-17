module Bosh::Monitor
  class Director

    def initialize(options, logger)
      @options = options
      @logger = logger
    end

    def get_deployments
      http = perform_request(:get, '/deployments')

      body   = http.response
      status = http.response_header.http_status

      if status != '200'
        raise DirectorError, "Cannot get deployments from director at #{http.uri}: #{status} #{body}"
      end

      parse_json(body, Array)
    end

    def get_deployment_vms(name)
      http = perform_request(:get, "/deployments/#{name}/vms")

      body   = http.response
      status = http.response_header.http_status

      if status != '200'
        raise DirectorError, "Cannot get deployment `#{name}' from director at #{http.uri}: #{status} #{body}"
      end

      parse_json(body, Array)
    end

    private

    def endpoint
      @options['endpoint'].to_s
    end

    def parse_json(json, expected_type = nil)
      result = Yajl::Parser.parse(json)

      if expected_type && !result.kind_of?(expected_type)
        raise DirectorError, "Invalid JSON response format, expected #{expected_type}, got #{result.class}"
      end

      result

    rescue Yajl::ParseError => e
      raise DirectorError, "Cannot parse director response: #{e.message}"
    end

    # JMS and GO: This effectively turns async requests into synchronous requests.
    # This is a very bad thing to do on eventmachine because it will block the single
    # event loop. This code should be removed and all requests converted
    # to "the eventmachine way".
    def perform_request(method, uri, options={})
      f = Fiber.current

      target_uri = endpoint + uri

      headers = {}
      unless options.fetch(:no_login, false)
        headers['authorization'] = auth_provider.auth_header
      end

      http = EM::HttpRequest.new(target_uri).send(method.to_sym, :head => headers)

      http.callback { f.resume(http) }
      http.errback  { f.resume(http) }

      Fiber.yield

    rescue URI::Error
      raise DirectorError, "Invalid URI: #{target_uri}"
    end

    def get_info
      http = perform_request(:get, '/info', no_login: true)

      body   = http.response
      status = http.response_header.http_status

      if status != '200'
        raise DirectorError, "Cannot get status from director at #{http.uri}: #{status} #{body}"
      end

      parse_json(body, Hash)
    end

    def auth_provider
      @auth_provider ||= AuthProvider.new(get_info, @options, @logger)
    end
  end
end
