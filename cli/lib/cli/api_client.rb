require "restclient"
require "progressbar"

module Bosh
  module Cli
    class ApiClient

      DIRECTOR_ERROR_CODES = [ 400, 403, 404, 500 ]

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1

      attr_reader :director_uri

      def initialize(director_uri, user, password)
        if director_uri.nil? || director_uri =~ /^\s*$/
          raise DirectorMissing, "no director URI given"
        end
        
        @director_uri = director_uri
        @user         = user
        @password     = password
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

      def upload_and_track(uri, content_type, filename, options = {})
        file = FileWithProgressBar.open(filename, "r")

        http_status, body, headers = post(uri, content_type, file)
        location = headers[:location]
        uploaded = http_status == 302

        status = \
        if uploaded
          if location =~ /\/tasks\/(\d+)\/?$/ # Doesn't look like we received task URI
            poll_task($1, options)
          else
            :non_trackable
          end
        else
          :failed
        end

        [ status, body ]
      ensure
        file.progress_bar.halt
      end

      def poll_task(task_id, options = {})
        polls = 0

        poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
        max_polls     = options[:max_polls]     || DEFAULT_MAX_POLLS

        task = DirectorTask.new(self, task_id)

        bosh_say("Tracking task output for task##{task_id}...")

        no_output_yet = true

        while true
          polls += 1
          state, output = task.state, task.output
          
          if output
            no_output_yet = false            
            bosh_say(output)
          end

          if no_output_yet && polls % 10 == 0
            bosh_say("Task state is '%s', waiting for output..." % [ state ])
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
        headers = headers.dup
        headers["Content-Type"] = content_type if content_type

        req = {
          :method => method, :url => @director_uri + uri,
          :payload => payload, :headers => headers,
          :user => @user, :password => @password,
          :timeout => 86400 * 3, :open_timeout => 300
        }

        status = body = response_headers = nil
        
        RestClient::Request.execute(req) do |response, request, result|
          status, body, response_headers = response.code, response.body, response.headers
        end

        if DIRECTOR_ERROR_CODES.include?(status)
          raise DirectorError, director_error_message(status, body)
        end

        [ status, body, response_headers ]

      rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
        raise DirectorInaccessible, "cannot access director (%s)" % [ e.message ]
      rescue SystemCallError => e
        raise DirectorError, "System call error while talking to director: #{e}"
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

    class FileWithProgressBar < ::File
      def progress_bar
        return @progress_bar if @progress_bar
        @progress_bar = ProgressBar.new(File.basename(self.path), File.size(self.path), Config.output)
        @progress_bar.file_transfer_mode
        @progress_bar
      end

      def read(*args)
        buf_len = args[0]
        result  = super(*args)

        if result && result.size > 0
          progress_bar.inc(result.size)
        else
          progress_bar.finish
        end

        result
      end
    end
    
  end
end
