# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli
    class Director
      include VersionCalc

      DIRECTOR_HTTP_ERROR_CODES = [400, 403, 500]

      DEFAULT_MAX_POLLS     = nil # Not limited
      DEFAULT_POLL_INTERVAL = 1
      API_TIMEOUT           = 86400 * 3
      CONNECT_TIMEOUT       = 30

      attr_reader :director_uri

      # The current task number. An accessor so it can be used in tests.
      # @return [String] The task number.
      attr_accessor :current_running_task

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
        # Backward compatibility: older directors return 200
        # only for logged in users
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
        upload_and_track("/stemcells", "application/x-compressed",
                         filename, :log_type => "event")
      end

      def get_version
        get_status["version"]
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
        if version_less(get_version, "0.3.5")
          get_json("/tasks?state=processing")
        else
          get_json("/tasks?state=processing,cancelling,queued")
        end
      end

      def list_recent_tasks(count = 30)
        count = [count.to_i, 100].min
        get_json("/tasks?limit=#{count}")
      end

      def get_release(name)
        get_json("/releases/#{name}")
      end

      def get_existing_packages(manifest_yaml)
        url = "/packages"
        status, body = post(url, "text/yaml", manifest_yaml)

        raise AuthError if status == 401
        raise DirectorError, "Director HTTP #{status}" if status != 200
        JSON.parse(body)
      end

      def get_deployment(name)
        status, body = get_json_with_status("/deployments/#{name}")
        if status == 404
          raise DeploymentNotFound, "Deployment `#{name}' not found"
        end
        body
      end

      def list_vms(name)
        status, body = get_json_with_status("/deployments/#{name}/vms")
        if status == 404
          raise DeploymentNotFound, "Deployment `#{name}' not found"
        end
        body
      end

      def upload_release(filename)
        upload_and_track("/releases", "application/x-compressed",
                         filename, :log_type => "event")
      end

      def delete_stemcell(name, version, options = {})
        track_options = { :log_type => "event" }
        track_options[:quiet] = options[:quiet] if options.has_key?(:quiet)
        request_and_track(:delete, "/stemcells/%s/%s" % [name, version],
                          nil, nil, track_options)
      end

      def delete_deployment(name, options = {})
        url = "/deployments/#{name}"
        query_params = []
        query_params << "force=true" if options[:force]
        url += "?#{query_params.join("&")}" if query_params.size > 0

        request_and_track(:delete, url, nil, nil, :log_type => "event")
      end

      def delete_release(name, options = {})
        url = "/releases/#{name}"

        query_params = []
        query_params << "force=true" if options[:force]
        query_params << "version=#{options[:version]}" if options[:version]

        url += "?#{query_params.join("&")}" if query_params.size > 0

        track_options = { :log_type => "event" }
        track_options[:quiet] = options[:quiet] if options.has_key?(:quiet)

        request_and_track(:delete, url, nil, nil, track_options)
      end

      def deploy(manifest_yaml, options = {})
        url = "/deployments"
        url += "?recreate=true" if options[:recreate]
        request_and_track(:post, url, "text/yaml",
                          manifest_yaml, :log_type => "event")
      end

      def setup_ssh(deployment_name, job, index, user, public_key, password)
        url = "/deployments/#{deployment_name}/ssh"
        payload = JSON.generate("command" => "setup",
                                "deployment_name" => deployment_name,
                                "target" => {
                                    "job" => job,
                                    "indexes" => [index].compact
                                },
                                "params" => {
                                    "user" => user,
                                    "public_key" => public_key,
                                    "password" => password })

        results = ""
        output_stream = lambda do |entries|
          results << entries
          ""
        end

        status, task_id = request_and_track(:post, url, "application/json",
                                            payload, :log_type => "result",
                                            :output_stream => output_stream)
        return nil if status != :done || task_id.nil?
        JSON.parse(results)
      end

      def cleanup_ssh(deployment_name, job, user_regex, indexes)
        indexes ||= []
        url = "/deployments/#{deployment_name}/ssh"
        payload = JSON.generate("command" => "cleanup",
                                "deployment_name" => deployment_name,
                                "target" => {
                                    "job" => job,
                                    "indexes" => indexes.compact
                                },
                                "params" => { "user_regex" => user_regex })
        request_and_track(:post, url, "application/json",
                          payload, :quiet => true)
      end

      def change_job_state(deployment_name, manifest_yaml,
          job_name, index, new_state)
        url = "/deployments/#{deployment_name}/jobs/#{job_name}"
        url += "/#{index}" if index
        url += "?state=#{new_state}"
        request_and_track(:put, url, "text/yaml",
                          manifest_yaml, :log_type => "event")
      end

      def rename_job(deployment_name, manifest_yaml, old_name, new_name,
                     force = nil)
        url = "/deployments/#{deployment_name}/jobs/#{old_name}"

        rename_params = ["new_name=#{new_name}"]
        rename_params << "force=true" if force

        url += "?#{rename_params.join("&")}" if rename_params.size > 0
        request_and_track(:put, url, "text/yaml",
                          manifest_yaml, :log_type => "event")
      end

      def fetch_logs(deployment_name, job_name, index, log_type, filters = nil)
        url = "/deployments/#{deployment_name}/jobs/#{job_name}" +
            "/#{index}/logs?type=#{log_type}&filters=#{filters}"
        status, task_id = request_and_track(:get, url, nil,
                                            nil, :log_type => "event")
        return nil if status != :done || task_id.nil?
        get_task_result(task_id)
      end

      def fetch_vm_state(deployment_name)
        url = "/deployments/#{deployment_name}/vms?format=full"
        vms = []
        # CLEANUP TODO output stream only being used for side effects
        output_stream = lambda do |vm_states|
          vm_states.to_s.split("\n").each do |vm_state|
            vms << JSON.parse(vm_state)
          end
          ""
        end

        status, task_id = request_and_track(:get, url, nil, nil,
                                            :log_type => "result",
                                            :output_stream => output_stream,
                                            :quiet => true)
        if status != :done || task_id.nil?
          raise DirectorError, "Failed to fetch VMs information from director"
        end
        vms
      end

      def download_resource(id)
        status, tmp_file, headers = get("/resources/#{id}", nil,
                                        nil, {}, :file => true)

        if status == 200
          tmp_file
        else
          raise DirectorError, "Cannot download resource `#{id}': " +
              "HTTP status #{status}"
        end
      end

      def create_property(deployment_name, property_name, value)
        url = "/deployments/#{deployment_name}/properties"
        payload = JSON.generate("name" => property_name, "value" => value)
        post(url, "application/json", payload)
      end

      def update_property(deployment_name, property_name, value)
        url = "/deployments/#{deployment_name}/properties/#{property_name}"
        payload = JSON.generate("value" => value)
        put(url, "application/json", payload)
      end

      def delete_property(deployment_name, property_name)
        url = "/deployments/#{deployment_name}/properties/#{property_name}"
        delete(url, "application/json")
      end

      def get_property(deployment_name, property_name)
        url = "/deployments/#{deployment_name}/properties/#{property_name}"
        get_json_with_status(url)
      end

      def list_properties(deployment_name)
        url = "/deployments/#{deployment_name}/properties"
        get_json(url)
      end

      def perform_cloud_scan(deployment_name)
        url = "/deployments/#{deployment_name}/scans"
        request_and_track(:post, url, nil, nil,
                          :log_type => "event", :log_only => true)
      end

      def list_problems(deployment_name)
        url = "/deployments/#{deployment_name}/problems"
        get_json(url)
      end

      def apply_resolutions(deployment_name, resolutions)
        url = "/deployments/#{deployment_name}/problems"
        request_and_track(:put, url, "application/json",
                          JSON.generate("resolutions" => resolutions),
                          :log_type => "event", :log_only => true)
      end

      def get_current_time
        status, body, headers = get("/info")
        Time.parse(headers[:date]) rescue nil
      end

      def get_time_difference
        # This includes the roundtrip to director
        ctime = get_current_time
        ctime ? Time.now - ctime : 0
      end

      def get_task(task_id)
        response_code, body = get("/tasks/#{task_id}")
        raise AuthError if response_code == 401
        raise MissingTask, "Task #{task_id} not found" if response_code == 404

        if response_code != 200
          raise TaskTrackError, "Got HTTP #{response_code} " +
              "while tracking task state"
        end

        JSON.parse(body)
      rescue JSON::ParserError
        raise TaskTrackError, "Cannot parse task JSON, " +
            "incompatible director version"
      end

      def get_task_state(task_id)
        get_task(task_id)["state"]
      end

      def get_task_result(task_id)
        get_task(task_id)["result"]
      end

      def get_task_output(task_id, offset, log_type = nil)
        uri = "/tasks/#{task_id}/output"
        uri += "?type=#{log_type}" if log_type

        headers = { "Range" => "bytes=#{offset}-" }
        response_code, body, headers = get(uri, nil, nil, headers)

        if response_code == 206 &&
            headers[:content_range].to_s =~ /bytes \d+-(\d+)\/\d+/
          new_offset = $1.to_i + 1
        else
          new_offset = nil
        end
        [body, new_offset]
      end

      def cancel_task(task_id)
        response_code, body = delete("/task/#{task_id}")
        raise AuthError if response_code == 401
        raise MissingTask, "No task##{task_id} found" if response_code == 404
        [body, response_code]
      end

      ##
      # Cancels the task currently running.
      def cancel_current
        body, response_code = cancel_task(@current_running_task)
        if (200..299).include?(response_code)
          say("Cancelling task ##{@current_running_task}.".red)
        end
      end

      ##
      # Returns whether there is a task currently running.
      #
      # @return [Boolean] Whether there is a task currently running.
      def has_current?
        unless @current_running_task
          return false
        end
        task_state = get_task_state(@current_running_task)
        task_state == "queued" || task_state == "processing"
      end

      [:post, :put, :get, :delete].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      def request_and_track(method, uri, content_type,
          payload = nil, options = {})
        http_status, body, headers = request(method, uri, content_type, payload)
        location   = headers[:location]
        redirected = http_status == 302
        task_id    = nil

        if redirected
          if location =~ /\/tasks\/(\d+)\/?$/ # Looks like we received task URI
            task_id = $1
            @current_running_task = task_id
            status = poll_task(task_id, options)
          else
            status = :non_trackable
          end
        else
          status = :failed
        end

        [status, task_id]
      end

      def upload_and_track(uri, content_type, filename, options = {})
        file = FileWithProgressBar.open(filename, "r")
        method = options[:method] || :post
        request_and_track(method, uri, content_type, file, options)
      ensure
        file.stop_progress_bar if file
      end

      def poll_task(task_id, options = {})
        polls = 0

        log_type      = options[:log_type]
        poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
        max_polls     = options[:max_polls]     || DEFAULT_MAX_POLLS
        start_time    = Time.now
        quiet         = options[:quiet]
        output_stream = options[:output_stream]
        log_only      = options[:log_only]

        task = DirectorTask.new(self, task_id, log_type)

        unless quiet || log_only
          say("Tracking task output for task##{task_id}...")
        end

        renderer = Bosh::Cli::TaskLogRenderer.create_for_log_type(log_type)
        renderer.time_adjustment = get_time_difference

        no_output_yet = true

        while true
          polls += 1
          state, output = task.state, task.output

          if output
            no_output_yet = false
            output = output_stream.call(output) unless output_stream.nil?
            renderer.add_output(output) unless quiet
          end

          if no_output_yet && polls % 10 == 0 && !quiet && !log_only
            say("Task state is '#{state}', waiting for output...")
          end

          renderer.refresh

          if state == "done"
            result = :done
            break
          elsif state == "error"
            result = :error
            break
          elsif state == "cancelled"
            result = :cancelled
            break
          elsif !max_polls.nil? && polls >= max_polls
            result = :track_timeout
            break
          end

          sleep(poll_interval)
        end

        unless quiet
          renderer.add_output(task.flush_output)
          renderer.finish(state)
        end

        return result if quiet
        return result if log_only && result == :done

        if Bosh::Cli::Config.interactive &&
            log_type != "debug" && result == :error
          confirm = ask("\nThe task has returned an error status, " +
                            "do you want to see debug log? [Yn]: ")
          if confirm.empty? || confirm =~ /y(es)?/i
            options.delete(:output_stream)
            poll_task(task_id, options.merge(:log_type => "debug"))
          else
            say("Please use 'bosh task #{task_id}' command " +
                    "to see the debug log".red)
            result
          end
        else
          nl
          status = "Task #{task_id}: state is '#{state}'"
          duration = renderer.duration || (Time.now - start_time)
          if result == :done
            status += ", took #{format_time(duration).green} to complete"
          end
          say(status)
          result
        end
      end

      def request(method, uri, content_type = nil, payload = nil,
          headers = {}, options = { })
        headers = headers.dup
        headers["Content-Type"] = content_type if content_type

        if options[:file]
          tmp_file = File.open(File.join(Dir.mktmpdir, "streamed-response"),
                               "w")

          response_reader = lambda do |part|
            tmp_file.write(part)
          end
        else
          response_reader = nil
        end

        response = perform_http_request(method, @director_uri + uri,
                                        payload, headers, &response_reader)

        if options[:file]
          tmp_file.close
          body = tmp_file.path
        else
          body = response.body
        end

        if DIRECTOR_HTTP_ERROR_CODES.include?(response.code)
          raise DirectorError, parse_error_message(response.code, body)
        end

        headers = response.headers.inject({}) do |hash, (k, v)|
          # Some HTTP clients symbolize headers, some do not.
          # To make it easier to switch between them, we try
          # to symbolize them ourselves.
          hash[k.to_s.downcase.gsub(/-/, "_").to_sym] = v
          hash
        end

        [response.code, body, headers]

      rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
        raise DirectorInaccessible,
              "cannot access director (#{e.message})"
      rescue SystemCallError => e
        raise DirectorError, "System call error while talking to director: #{e}"
      end

      def parse_error_message(status, body)
        parsed_body = JSON.parse(body.to_s)

        if parsed_body["code"] && parsed_body["description"]
          "Director error %s: %s" % [parsed_body["code"],
                                     parsed_body["description"]]
        else
          "Director error (HTTP %s): %s" % [status, body]
        end
      rescue JSON::ParserError
        "Director error (HTTP %s): %s" % [status, body]
      end

      private

      def perform_http_request(method, uri, payload = nil, headers = {}, &block)
        http_client = HTTPClient.new

        http_client.send_timeout = API_TIMEOUT
        http_client.receive_timeout = API_TIMEOUT
        http_client.connect_timeout = CONNECT_TIMEOUT

        # HTTPClient#set_auth doesn't seem to work properly,
        # injecting header manually instead.
        # TODO: consider using vanilla Net::HTTP
        if @user && @password
          headers["Authorization"] = "Basic " +
              Base64.encode64("#{@user}:#{@password}").strip
        end

        http_client.request(method, uri, :body => payload,
                            :header => headers, &block)

      rescue HTTPClient::BadResponseError => e
        err("Received bad HTTP response from director: #{e}")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError
        raise # We handle these upstream
      rescue => e
        # httpclient (sadly) doesn't have a generic exception
        err("REST API call exception: #{e}")
      end

      def get_json(url)
        status, body = get_json_with_status(url)
        raise AuthError if status == 401
        raise DirectorError, "Director HTTP #{status}" if status != 200
        body
      end

      def get_json_with_status(url)
        status, body, headers = get(url, "application/json")
        body = JSON.parse(body) if status == 200
        [status, body]
      rescue JSON::ParserError
        raise DirectorError, "Cannot parse director response: #{body}"
      end

    end

    class FileWithProgressBar < ::File
      def progress_bar
        return @progress_bar if @progress_bar
        out = Bosh::Cli::Config.output || StringIO.new
        @progress_bar = ProgressBar.new(File.basename(self.path),
                                        File.size(self.path), out)
        @progress_bar.file_transfer_mode
        @progress_bar
      end

      def stop_progress_bar
        progress_bar.halt unless progress_bar.finished?
      end

      def size
        File.size(self.path)
      end

      def read(*args)
        result = super(*args)

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
