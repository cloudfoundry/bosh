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

    def get_deployment_instances_full(name, recursive_counter=0)
      body, status, headers = perform_request(:get, "/deployments/#{name}/instances?format=full")
      sleep_amount_seconds = 1
      location = headers['location']
      unless !location.nil? && location.include?('task')
        raise DirectorError, "Can not find 'location' response header to retrieve the task location"
      end
      counter = 0
      # States are documented here: https://bosh.io/docs/director-api-v1/#list-tasks
      truthy_states = %w(cancelled cancelling done error timeout)
      falsy_states = %w(queued processing)
      body = nil, status = nil, state = nil
      loop do
        counter = counter + 1
        body, status = perform_request(:get, location)
        if status == 206 || body.nil? || body.empty?
          sleep_amount_seconds = counter + sleep_amount_seconds
          sleep(sleep_amount_seconds)
          next
        end
        json_output = parse_json(body, Hash)
        state = json_output['state']
        if truthy_states.include?(state) || counter > 5
          @logger.warn("The number of retries to fetch instance details for deployment '#{name}' has exceeded. Could not get the expected response from '#{location}'")
          break
        end
        sleep_amount_seconds = counter + sleep_amount_seconds
        sleep(sleep_amount_seconds)
      end
      updated_body = nil
      if state == 'done'
        body, status = perform_request(:get, "#{location}/output?type=result")
        if status!= 200 || body.nil? || body.empty?
          raise DirectorError, "Fetching full instance details for deployment '#{name}' failed"
        end
        updated_body = "[#{body.chomp.gsub(/\R+/, ',')}]"
        return parse_json(updated_body, Array)
      else
        if recursive_counter > 0
          return updated_body, state
        end
        @logger.warn("Could not fetch instance details for deployment '#{name}' in the first attempt, retrying once more ...")
        return get_deployment_instances_full(name, recursive_counter + 1)
      end
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
      if !request_path.nil?
       request_path = request_path.sub(endpoint, '')
      end
      parsed_endpoint = URI.parse(endpoint + (request_path || ''))
      headers = options['headers'] || {}
      headers['authorization'] = auth_provider.auth_header unless options.fetch(:no_login, false)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
      async_endpoint = Async::HTTP::Endpoint.parse(parsed_endpoint.to_s, ssl_context: ssl_context)
      response = Async::HTTP::Internet.send(method.to_sym, async_endpoint, headers)

      body   = response.read
      status = response.status

      [body, status, response.headers]
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
