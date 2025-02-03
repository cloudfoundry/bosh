require 'async/http/internet/instance'

module Bosh::Monitor
  class Director
    def initialize(options, logger)
      @options = options
      @logger = logger
    end

    def deployments
      body, status = perform_request(:get, '/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')

      raise DirectorError, "Cannot get deployments from director at #{endpoint}/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true: #{status} #{body}" if status != 200

      parse_json(body, Array)
    end

    def resurrection_config
      body, status = perform_request(:get, '/configs?type=resurrection&latest=true')

      raise DirectorError, "Cannot get resurrection config from director at #{endpoint}/configs?type=resurrection&latest=true: #{status} #{body}" if status != 200

      parse_json(body, Array)
    end

    def get_deployment_instances(name)
      body, status = perform_request(:get, "/deployments/#{name}/instances")

      raise DirectorError, "Cannot get deployment '#{name}' from director at #{endpoint}/deployments/#{name}/instances: #{status} #{body}" if status != 200

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

    def perform_request(method, request_path, options = {})
      parsed_endpoint = URI.parse(endpoint + request_path)
      headers = {}
      headers['authorization'] = auth_provider.auth_header unless options.fetch(:no_login, false)

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
      async_endpoint = Async::HTTP::Endpoint.parse(parsed_endpoint.to_s, ssl_context: ssl_context)
      response = Async::HTTP::Internet.send(method.to_sym, async_endpoint, headers)

      body   = response.read
      status = response.status

      [body, status]
    rescue URI::Error
      raise DirectorError, "Invalid URI: #{endpoint + request_path}"
    rescue => e
      raise DirectorError, "Unable to send #{method} #{parsed_endpoint.path} to director: #{e}"
    ensure
      response.close if response
    end

    def info
      body, status = perform_request(:get, '/info', no_login: true)

      raise DirectorError, "Cannot get status from director at #{http.req.uri}: #{status} #{body}" if status != 200

      parse_json(body, Hash)
    end

    def auth_provider
      @auth_provider ||= AuthProvider.new(info, @options, @logger)
    end
  end
end
