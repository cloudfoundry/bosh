require "restclient"
require "progressbar"
require "json"

module Bosh
  module Cli
    class Director

      DIRECTOR_HTTP_ERROR_CODES = [ 400, 403, 500 ]

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1
      API_TIMEOUT           = 86400 * 3
      OPEN_TIMEOUT          = 30

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
        get_status
        true
      rescue AuthError
        true # For compatibility with directors that return 401 for /info
      rescue DirectorError
        false
      end

      def authenticated?
        status = get_status
        # Backward compatibility: older directors return 200 only for logged in users
        return true if !status.has_key?("version")
        !status["user"].nil?
      rescue DirectorError
        false
      end

      def create_user(username, password)
        payload = JSON.generate("username" => username, "password" => password)
        response_code, body = post("/users", "application/json", payload)
        response_code == 204
      end

      def upload_stemcell(filename)
        upload_and_track("/stemcells", "application/x-compressed", filename)
      end

      def get_status
        get_json("/info")
      end

      def list_stemcells
        get_json("/stemcells")
      end

      def list_releases
        get_json("/releases")
      end

      def list_deployments
        get_json("/deployments")
      end

      def list_running_tasks
        get_json("/tasks?state=processing")
      end

      def list_recent_tasks(count = 30)
        count = [count.to_i, 100].min
        get_json("/tasks?limit=#{count}")
      end

      def get_release(name)
        get_json("/releases/#{name}")
      end

      def get_deployment(name)
        status, body = get_json_with_status("/deployments/#{name}")
        raise DeploymentNotFound, "Deployment `#{name}' not found" if status == 404
        body
      end

      def upload_release(filename)
        upload_and_track("/releases", "application/x-compressed", filename)
      end

      def delete_stemcell(name, version)
        request_and_track(:delete, "/stemcells/%s/%s" % [ name, version ], nil, nil)
      end

      def delete_deployment(name)
        request_and_track(:delete, "/deployments/%s" % [ name ], nil, nil)
      end

      def delete_release(name, options = {})
        url = "/releases/#{name}"
        url += "?force=true" if options[:force]
        request_and_track(:delete, url, nil, nil)
      end

      def deploy(filename, options = {})
        url = "/deployments"
        url += "?force=true" if options[:force]
        upload_and_track(url, "text/yaml", filename)
      end

      def get_task_state(task_id)
        response_code, body = get("/tasks/#{task_id}")
        raise AuthError if response_code == 401
        raise MissingTask, "No task##{@task_id} found" if response_code == 404
        raise TaskTrackError, "Got HTTP #{response_code} while tracking task state" if response_code != 200
        JSON.parse(body)["state"]
      rescue JSON::ParserError
        raise TaskTrackError, "Cannot parse task JSON, incompatible director version"
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

      def request_and_track(method, uri, content_type, payload = nil, options = {})
        http_status, body, headers = request(method, uri, content_type, payload)
        location   = headers[:location]
        redirected = http_status == 302

        status = \
        if redirected
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

      def request(method, uri, content_type = nil, payload = nil, headers = {})
        headers = headers.dup
        headers["Content-Type"] = content_type if content_type

        req = {
          :method => method, :url => @director_uri + uri,
          :payload => payload, :headers => headers,
          :user => @user, :password => @password,
          :timeout => API_TIMEOUT, :open_timeout => OPEN_TIMEOUT
        }

        status, body, response_headers = perform_http_request(req)

        if DIRECTOR_HTTP_ERROR_CODES.include?(status)
          raise DirectorError, parse_error_message(status, body)
        end

        [ status, body, response_headers ]

      rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
        raise DirectorInaccessible, "cannot access director (%s)" % [ e.message ]
      rescue SystemCallError => e
        raise DirectorError, "System call error while talking to director: #{e}"
      end

      private

      def perform_http_request(req)
        result = nil
        RestClient::Request.execute(req) do |response, request, req_result|
          result = [ response.code, response.body, response.headers ]
        end
        result
      rescue Net::HTTPBadResponse => e
        err("Received bad HTTP response from director: #{e}")
      rescue RestClient::Exception => e
        err("REST API call exception: #{e}")
      end

      def get_json(url)
        status, body = get_json_with_status(url)
        raise AuthError if status == 401
        raise DirectorError if status != 200
        body
      end

      def get_json_with_status(url)
        status, body, headers = get(url, "application/json")
        body = JSON.parse(body) if status == 200
        [ status, body ]
      rescue JSON::ParserError
        raise DirectorError, "Cannot parse director response: #{body}"
      end

      def parse_error_message(status, body)
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
