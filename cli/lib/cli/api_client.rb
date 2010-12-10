$:.unshift(File.expand_path("../../../vendor/gems/httpclient-2.1.5.2/lib", __FILE__))
require "httpclient"

module Bosh
  module Cli
    class ApiClient

      DIRECTOR_ERROR_CODES = [ 400, 403, 404, 500 ]

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1

      attr_reader :director_uri

      def initialize(director_uri, username, password)
        director_uri  = "http://#{director_uri}" unless director_uri =~ /^[^:]*:\/\//
        @director_uri = URI.parse(director_uri)

        @client = HTTPClient.new(:agent_name => "bosh-cli #{Bosh::Cli::VERSION}")
        @client.set_auth(nil, username, password)
      rescue URI::Error
        raise DirectorError, "Invalid director URI '#{director_uri}'"
      end

      def can_access_director?
        [401, 200].include?(get("/status")[0])
      end

      def authenticated?
        get("/status")[0] == 200
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

      def request(method, uri, content_type = nil, payload = nil, headers = {})
        headers["Content-Type"] = content_type if content_type

        response = @client.request(method, @director_uri + uri, nil, payload, headers)
        status   = response.status_code
        body     = response.content
        # httpclient uses  array format for storing headers,
        # so we just convert it to hash for easier access
        headers  = response.header.get.inject({}) { |h, e| h[e[0]] = e[1]; h }

        if DIRECTOR_ERROR_CODES.include?(status)
          raise DirectorError, director_error_message(status, body)
        end

        [ status, body, headers ]

      rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
        raise DirectorInaccessible, "cannot access director (%s)" % [ e.message ]
      end

      
      def director_error_message(status, body)
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
