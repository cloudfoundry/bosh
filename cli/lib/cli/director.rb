require "restclient"
require "progressbar"
require "json"

module Bosh
  module Cli
    class Director

      DIRECTOR_ERROR_CODES = [ 400, 403, 404, 500 ]

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1

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

      def create_user(username, password)
        payload = JSON.generate("username" => username, "password" => password)        
        response_code, body = post("/users", "application/json", payload)
        response_code == 200
      end

      def upload_stemcell(filename)
        upload_and_track("/stemcells", "application/x-compressed", filename)
      end

      def upload_release(filename)
        upload_and_track("/releases", "application/x-compressed", filename)
      end

      def delete_stemcell(name, version)
        request_and_track(:delete, "/stemcells/%s/%s" % [ name, version ], nil, nil)
      end

      def deploy(filename)
        upload_and_track("/deployments", "text/yaml", filename)
      end

      def get_task_state(task_id)
        response_code, body = get("/tasks/#{task_id}")
        raise AuthError if response_code == 401
        raise MissingTask, "No task##{@task_id} found" if response_code == 404
        raise TaskTrackError, "Got HTTP #{response_code} while tracking task state" if response_code != 200
        return body
      end

      def get_task_output(task_id, offset)
        response_code, body, headers = get("/tasks/#{task_id}/output", nil, nil, { "Range" => "bytes=%d-" % [ offset ] })
        new_offset = \
        if response_code == 206 && headers[:content_range].to_s =~ /bytes \d+-(\d+)\/\d+/
          $1.to_i + 1
        else
          nil
        end
        [ body, new_offset ]
      end

      [ :post, :put, :get, :delete ].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      def request_and_track(method, uri, content_type, payload, options = {})
        http_status, body, headers = request(method, uri, content_type, payload)
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
      end

      def upload_and_track(uri, content_type, filename, options = {})
        file = FileWithProgressBar.open(filename, "r")
        request_and_track(:post, uri, content_type, file)
      ensure
        file.stop_progress_bar if file
      end

      def poll_task(task_id, options = {})
        polls = 0

        poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
        max_polls     = options[:max_polls]     || DEFAULT_MAX_POLLS

        task = DirectorTask.new(self, task_id)

        say("Tracking task output for task##{task_id}...")

        no_output_yet = true

        while true
          polls += 1
          state, output = task.state, task.output
          
          if output
            no_output_yet = false            
            say(output)
          end

          if no_output_yet && polls % 10 == 0
            say("Task state is '%s', waiting for output..." % [ state ])
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

        say(task.flush_output)
        say("Task #{task_id}: state is '#{state}'")
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
        out = Bosh::Cli::Config.output || StringIO.new
        @progress_bar = ProgressBar.new(File.basename(self.path), File.size(self.path), out)
        @progress_bar.file_transfer_mode
        @progress_bar
      end

      def stop_progress_bar
        progress_bar.halt unless progress_bar.finished?        
      end

      def read(*args)
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
