module Bosh::Monitor
  class Director
    def initialize(options, logger)
      @options = options
      @logger = logger
    end

    def deployments
      http = perform_request(:get, '/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')

      body   = http.response
      status = http.response_header.status

      raise DirectorError, "Cannot get deployments from director at #{http.req.uri}: #{status} #{body}" if status != 200

      parse_json(body, Array)
    end

    def resurrection_config
      http = perform_request(:get, '/configs?type=resurrection&latest=true')

      body   = http.response
      status = http.response_header.status

      raise DirectorError, "Cannot get resurrection config from director at #{http.req.uri}: #{status} #{body}" if status != 200

      parse_json(body, Array)
    end

    def get_deployment_instances(name)
      http = perform_request(:get, "/deployments/#{name}/instances")

      body   = http.response
      status = http.response_header.status

      raise DirectorError, "Cannot get deployment '#{name}' from director at #{http.req.uri}: #{status} #{body}" if status != 200

      parse_json(body, Array)
    end

    private

    def endpoint
      @options['endpoint'].to_s
    end

    def parse_json(json, expected_type = nil)
      result = JSON.parse(json)

      if expected_type && !result.is_a?(expected_type)
        raise DirectorError, "Invalid JSON response format, expected #{expected_type}, got #{result.class}"
      end

      result
    rescue JSON::ParserError => e
      raise DirectorError, "Cannot parse director response: #{e.message}"
    end

    # JMS and GO: This effectively turns async requests into synchronous requests.
    # This is a very bad thing to do on eventmachine because it will block the single
    # event loop. This code should be removed and all requests converted
    # to "the eventmachine way".
    def perform_request(method, uri, options = {})
      f = Fiber.current

      target_uri = endpoint + uri

      headers = {}
      headers['authorization'] = auth_provider.auth_header unless options.fetch(:no_login, false)

      http = EM::HttpRequest.new(target_uri, tls: { verify_peer: false }).send(method.to_sym, head: headers)

      http.callback { f.resume(http) }
      http.errback  { f.resume(http) }

      Fiber.yield
    rescue URI::Error
      raise DirectorError, "Invalid URI: #{target_uri}"
    end

    def info
      http = perform_request(:get, '/info', no_login: true)

      body   = http.response
      status = http.response_header.status

      raise DirectorError, "Cannot get status from director at #{http.req.uri}: #{status} #{body}" if status != 200

      parse_json(body, Hash)
    end

    def auth_provider
      @auth_provider ||= AuthProvider.new(info, @options, @logger)
    end
  end
end
