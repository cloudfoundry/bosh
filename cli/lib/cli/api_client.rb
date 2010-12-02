require "httpclient"

module Bosh
  module Cli
    class ApiClient

      DEFAULT_MAX_POLLS     = 300
      DEFAULT_POLL_INTERVAL = 1

      def initialize(base_uri, username, password)
        @base_uri  = URI.parse(base_uri)
        @client    = HTTPClient.new(:agent_name => "bosh-cli #{Bosh::Cli::VERSION}")
        @client.set_auth(nil, username, password)
      rescue URI::Error
        raise ArgumentError, "#{base_uri} is an invalid URI, cannot perform API calls"
      end

      [ :post, :put, :get, :delete ].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      def upload_and_track(uri, content_type, file, options = {})
        status, body, headers = post(uri, content_type, File.read(file))
        location = headers["Location"]

        uploaded = status == 302

        if uploaded
          if location !~ /^.+(\d+)\/?$/ # Doesn't look like we received URI
            return :non_trackable
          end

          self.poll_job_status(location, options) do |polls, status|
            yield(polls, status) if block_given?
          end
        else
          :failed
        end        
      end

      def poll_job_status(job_status_uri, options = {})
        polls = 0

        poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
        max_polls     = options[:max_polls] || DEFAULT_MAX_POLLS

        while true
          polls += 1          
          status, body = self.get(job_status_uri)

          yield polls, body if block_given? # For tracking progress

          return :track_error   if status != 200 || body == "error"
          return :done          if body == "done"
          return :track_timeout if polls >= max_polls

          wait(poll_interval)
        end
      end

      def wait(interval) # Extracted for easier testing
        sleep(interval)
      end

      private

      def request(method, uri, content_type = nil, payload = nil)
        headers = {}
        headers["Content-Type"] = content_type if content_type

        response = @client.request(method, @base_uri + uri, nil, payload, headers)

        status  = response.status_code
        body    = response.content

        # httpclient uses  array format for storing headers,
        # so we just convert it to hash for be
        headers = response.header.get.inject({}) { |h, e| h[e[0]] = e[1]; h }

        [ status, body, headers ]
        # TODO: rescue URI::Error?
      end
      
    end
  end
end
