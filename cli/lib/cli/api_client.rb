$:.unshift(File.expand_path("../../../vendor/gems/httpclient-2.1.5.2/lib", __FILE__))
require "httpclient"

module Bosh
  module Cli
    class ApiClient

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1

      attr_reader :base_uri

      def initialize(base_uri, username, password)
        base_uri   = "http://#{base_uri}" unless base_uri =~ /^[^:]*:\/\//
        @base_uri  = URI.parse(base_uri)

        @client    = HTTPClient.new(:agent_name => "bosh-cli #{Bosh::Cli::VERSION}")
        @client.set_auth(nil, username, password)
      rescue URI::Error
        raise ArgumentError, "'#{base_uri}' is an invalid URI, cannot perform API calls"
      end

      def can_access_director?
        [401, 200].include?(get("/status")[0])
      rescue StandardError => e
        false
      end

      def authenticated?
        get("/status")[0] == 200
      rescue StandardError => e
        false
      end

      [ :post, :put, :get, :delete ].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      def upload_and_track(uri, content_type, file, options = {})
        http_status, body, headers = post(uri, content_type, File.read(file))
        location = headers["Location"]

        uploaded = http_status == 302

        status = \
        if uploaded
          if location =~ /\/tasks\/(\d+)\/?$/ # Doesn't look like we received URI
            poll_task($1, options)
          else
            :non_trackable
          end
        else
          :failed
        end

        [ status, body ]
      end

      def poll_task(task_id, options = {})
        polls = 0

        poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
        max_polls     = options[:max_polls]     || DEFAULT_MAX_POLLS

        task = DirectorTask.new(self, task_id)

        bosh_say("Tracking job output for job##{task_id}...")

        no_output_yet = true

        while true
          polls += 1
          state, output = task.state, task.output
          
          if output
            no_output_yet = false            
            bosh_say(output)
          end

          if no_output_yet && polls % 10 == 0
            bosh_say("Job state is '%s', waiting for output..." % [ state ])
          end
          
          if state == "done"
            result = :done
            break
          elsif state == "error"
            result = :error
            break
          elsif !max_polls.nil? && polls >= max_polls
            result = :track_timeout
            break
          end

          wait(poll_interval)
        end

        bosh_say(task.flush_output)
        return result
      end

      def wait(interval) # Extracted for easier testing
        sleep(interval)
      end

      private

      def say(message)
        Config.output.puts(message)
      end

      def request(method, uri, content_type = nil, payload = nil, headers = {})
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
