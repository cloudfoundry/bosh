require 'cli/core_ext'
require 'cli/errors'
require 'cli/cloud_config'

require 'json'
require 'httpclient'
require 'base64'
require 'cli/file_with_progress_bar'

module Bosh
  module Cli
    module Client
      class Director

        DIRECTOR_HTTP_ERROR_CODES = [400, 401, 403, 404, 500]

        API_TIMEOUT     = 86400 * 3
        CONNECT_TIMEOUT = 30

        attr_reader :director_uri

        # Options can include:
        # * :no_track => true - do not use +TaskTracker+ for long-running
        #                       +request_and_track+ calls
        def initialize(director_uri, credentials = nil, options = {})
          if director_uri.nil? || director_uri =~ /^\s*$/
            raise DirectorMissing, 'no director URI given'
          end

          @director_uri        = URI.parse(director_uri)
          @director_ip         = Resolv.getaddresses(@director_uri.host).last
          @scheme              = @director_uri.scheme
          @port                = @director_uri.port
          @credentials         = credentials
          @track_tasks         = !options.delete(:no_track)
          @num_retries         = options.fetch(:num_retries, 5)
          @retry_wait_interval = options.fetch(:retry_wait_interval, 5)
          @ca_cert             = options[:ca_cert]
        end

        def uuid
          @uuid ||= get_status['uuid']
        end

        def exists?
          get_status
          true
        rescue AuthError
          true # For compatibility with directors that return 401 for /info
        rescue DirectorError
          false
        end

        def wait_until_ready
          num_retries.times do
            return if exists?
            sleep retry_wait_interval
          end
        end

        def login(username, password)
          @credentials = BasicCredentials.new(username, password)
          authenticated?
        end

        def authenticated?
          # getting status verifies credentials
          # if credentials are wrong it will raise DirectorError
          status = get_status
          # Backward compatibility: older directors return 200
          # only for logged in users
          return true if !status.has_key?('version')
          !status['user'].nil?
        rescue DirectorError
          false
        end

        def create_user(username, password)
          payload          = JSON.generate('username' => username, 'password' => password)
          response_code, _ = post('/users', 'application/json', payload)
          response_code == 204
        end

        def delete_user(username)
          response_code, _ = delete("/users/#{username}")
          response_code == 204
        end

        def upload_stemcell(filename, options = {})
          options                = options.dup
          options[:content_type] = 'application/x-compressed'

          upload_and_track(:post, stemcells_path(options), filename, options)
        end

        def upload_remote_stemcell(stemcell_location, options = {})
          options                = options.dup
          payload                = { 'location' => stemcell_location }
          options[:payload]      = JSON.generate(payload)
          options[:content_type] = 'application/json'

          request_and_track(:post, stemcells_path(options), options)
        end

        def get_version
          get_status['version']
        end

        def get_status
          get_json('/info')
        end

        def list_stemcells
          get_json('/stemcells')
        end

        def list_releases
          get_json('/releases')
        end

        def list_deployments
          get_json('/deployments')
        end

        def list_errands(deployment_name)
          get_json("/deployments/#{deployment_name}/errands")
        end

        def list_running_tasks(verbose = 1)
          get_json("/tasks?state=processing,cancelling,queued&verbose=#{verbose}")
        end

        def list_recent_tasks(count = 30, verbose = 1)
          get_json("/tasks?limit=#{count}&verbose=#{verbose}")
        end

        def get_release(name)
          get_json("/releases/#{name}")
        end

        def inspect_release(name, version)
          url = "/releases/#{name}"

          extras = []
          extras << ['version', version]

          get_json(add_query_string(url, extras))
        end

        def match_packages(manifest_yaml)
          url          = '/packages/matches'
          status, body = post(url, 'text/yaml', manifest_yaml)

          if status == 200
            JSON.parse(body)
          else
            err(parse_error_message(status, body))
          end
        end

        def match_compiled_packages(manifest_yaml)
          url          = '/packages/matches_compiled'
          status, body = post(url, 'text/yaml', manifest_yaml)

          if status == 200
            JSON.parse(body)
          else
            err(parse_error_message(status, body))
          end
        end

        def get_deployment(name)
          _, body = get_json_with_status("/deployments/#{name}")
          body
        end

        def list_vms(name)
          _, body = get_json_with_status("/deployments/#{name}/vms")
          body
        end

        def upload_release(filename, options = {})
          options                = options.dup
          options[:content_type] = 'application/x-compressed'

          upload_and_track(:post, releases_path(options), filename, options)
        end

        def upload_remote_release(release_location, options = {})
          options                = options.dup
          payload                = { 'location' => release_location }
          options[:payload]      = JSON.generate(payload)
          options[:content_type] = 'application/json'

          request_and_track(:post, releases_path(options), options)
        end

        def delete_stemcell(name, version, options = {})
          options = options.dup
          force   = options.delete(:force)

          url = "/stemcells/#{name}/#{version}"

          extras = []
          extras << ['force', 'true'] if force

          request_and_track(:delete, add_query_string(url, extras), options)
        end

        def delete_deployment(name, options = {})
          options = options.dup
          force   = options.delete(:force)

          url = "/deployments/#{name}"

          extras = []
          extras << ['force', 'true'] if force

          request_and_track(:delete, add_query_string(url, extras), options)
        end

        def delete_release(name, options = {})
          options = options.dup
          force   = options.delete(:force)
          version = options.delete(:version)

          url = "/releases/#{name}"

          extras = []
          extras << ['force', 'true'] if force
          extras << ['version', version] if version

          request_and_track(:delete, add_query_string(url, extras), options)
        end

        def deploy(manifest_yaml, options = {})
          options = options.dup

          recreate               = options.delete(:recreate)
          skip_drain             = options.delete(:skip_drain)
          options[:content_type] = 'text/yaml'
          options[:payload]      = manifest_yaml

          url = '/deployments'

          extras = []
          extras << ['recreate', 'true']   if recreate
          extras << ['skip_drain', skip_drain] if skip_drain

          request_and_track(:post, add_query_string(url, extras), options)
        end

        def setup_ssh(deployment_name, job, index, user,
          public_key, password, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/ssh"

          payload = {
            'command'         => 'setup',
            'deployment_name' => deployment_name,
            'target'          => {
              'job'     => job,
              'indexes' => [index].compact
            },
            'params'          => {
              'user'       => user,
              'public_key' => public_key,
              'password'   => password
            }
          }

          options[:payload]      = JSON.generate(payload)
          options[:content_type] = 'application/json'

          request_and_track(:post, url, options)
        end

        def cleanup_ssh(deployment_name, job, user_regex, indexes, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/ssh"

          payload = {
            'command'         => 'cleanup',
            'deployment_name' => deployment_name,
            'target'          => {
              'job'     => job,
              'indexes' => (indexes || []).compact
            },
            'params'          => { 'user_regex' => user_regex }
          }

          options[:payload]      = JSON.generate(payload)
          options[:content_type] = 'application/json'
          options[:task_success_state] = :queued

          request_and_track(:post, url, options)
        end

        def change_job_state(deployment_name, manifest_yaml,
          job_name, index, new_state, options = {})
          options = options.dup

          skip_drain = !!options.delete(:skip_drain)

          url = "/deployments/#{deployment_name}/jobs/#{job_name}"
          url += "/#{index}" if index
          url += "?state=#{new_state}"
          url += "&skip_drain=true" if skip_drain

          options[:payload]      = manifest_yaml
          options[:content_type] = 'text/yaml'

          request_and_track(:put, url, options)
        end

        def change_vm_resurrection(deployment_name, job_name, index, value)
          url     = "/deployments/#{deployment_name}/jobs/#{job_name}/#{index}/resurrection"
          payload = JSON.generate('resurrection_paused' => value)
          put(url, 'application/json', payload)
        end

        def change_vm_resurrection_for_all(value)
          url     = "/resurrection"
          payload = JSON.generate('resurrection_paused' => value)
          put(url, 'application/json', payload)
        end

        def rename_job(deployment_name, manifest_yaml, old_name, new_name,
          force = false, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/jobs/#{old_name}"

          extras = []
          extras << ['new_name', new_name]
          extras << ['force', 'true'] if force

          options[:content_type] = 'text/yaml'
          options[:payload]      = manifest_yaml

          request_and_track(:put, add_query_string(url, extras), options)
        end

        def fetch_logs(deployment_name, job_name, index, log_type,
          filters = nil, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/jobs/#{job_name}"
          url += "/#{index}/logs?type=#{log_type}&filters=#{filters}"

          status, task_id = request_and_track(:get, url, options)

          return nil if status != :done
          get_task_result(task_id)
        end

        def fetch_vm_state(deployment_name, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/vms?format=full"

          status, task_id = request_and_track(:get, url, options)

          if status != :done
            raise DirectorError, 'Failed to fetch VMs information from director'
          end

          output = get_task_result_log(task_id)

          output.to_s.split("\n").map do |vm_state|
            JSON.parse(vm_state)
          end
        end

        def download_resource(id)
          status, tmp_file, _ = get("/resources/#{id}",
                                    nil, nil, {}, :file => true)

          if status == 200
            tmp_file
          else
            raise DirectorError,
                  "Cannot download resource `#{id}': HTTP status #{status}"
          end
        end

        def create_property(deployment_name, property_name, value)
          url     = "/deployments/#{deployment_name}/properties"
          payload = JSON.generate('name' => property_name, 'value' => value)
          post(url, 'application/json', payload)
        end

        def update_property(deployment_name, property_name, value)
          url     = "/deployments/#{deployment_name}/properties/#{property_name}"
          payload = JSON.generate('value' => value)
          put(url, 'application/json', payload)
        end

        def delete_property(deployment_name, property_name)
          url = "/deployments/#{deployment_name}/properties/#{property_name}"
          delete(url, 'application/json')
        end

        def get_property(deployment_name, property_name)
          url = "/deployments/#{deployment_name}/properties/#{property_name}"
          get_json_with_status(url)
        end

        def list_properties(deployment_name)
          url = "/deployments/#{deployment_name}/properties"
          get_json(url)
        end

        def take_snapshot(deployment_name, job = nil, index = nil, options = {})
          options = options.dup

          if job && index
            url = "/deployments/#{deployment_name}/jobs/#{job}/#{index}/snapshots"
          else
            url = "/deployments/#{deployment_name}/snapshots"
          end

          request_and_track(:post, url, options)
        end

        def list_snapshots(deployment_name, job = nil, index = nil)
          if job && index
            url = "/deployments/#{deployment_name}/jobs/#{job}/#{index}/snapshots"
          else
            url = "/deployments/#{deployment_name}/snapshots"
          end
          get_json(url)
        end

        def delete_all_snapshots(deployment_name, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/snapshots"

          request_and_track(:delete, url, options)
        end

        def delete_snapshot(deployment_name, snapshot_cid, options = {})
          options = options.dup

          url = "/deployments/#{deployment_name}/snapshots/#{snapshot_cid}"

          request_and_track(:delete, url, options)
        end

        def perform_cloud_scan(deployment_name, options = {})
          options = options.dup
          url     = "/deployments/#{deployment_name}/scans"

          request_and_track(:post, url, options)
        end

        def list_problems(deployment_name)
          url = "/deployments/#{deployment_name}/problems"
          get_json(url)
        end

        def apply_resolutions(deployment_name, resolutions, options = {})
          options = options.dup

          url                    = "/deployments/#{deployment_name}/problems"
          options[:content_type] = 'application/json'
          options[:payload]      = JSON.generate('resolutions' => resolutions)

          request_and_track(:put, url, options)
        end

        def get_current_time
          _, _, headers = get('/info')
          Time.parse(headers[:date]) rescue nil
        end

        def get_time_difference
          # This includes the round-trip to director
          ctime = get_current_time
          ctime ? Time.now - ctime : 0
        end

        def get_task(task_id)
          response_code, body = get("/tasks/#{task_id}")
          raise AuthError if response_code == 401
          raise MissingTask, "Task #{task_id} not found" if response_code == 404

          if response_code != 200
            raise TaskTrackError, "Got HTTP #{response_code} " +
              'while tracking task state'
          end

          JSON.parse(body)
        rescue JSON::ParserError
          raise TaskTrackError, 'Cannot parse task JSON, ' +
            'incompatible director version'
        end

        def get_task_state(task_id)
          get_task(task_id)['state']
        end

        def get_task_result(task_id)
          get_task(task_id)['result']
        end

        def get_task_result_log(task_id)
          log, _ = get_task_output(task_id, 0, 'result')
          log
        end

        def get_task_output(task_id, offset, log_type = nil)
          uri = "/tasks/#{task_id}/output"
          uri += "?type=#{log_type}" if log_type

          headers                      = { 'Range' => "bytes=#{offset}-" }
          response_code, body, headers = get(uri, nil, nil, headers)

          if response_code == 206 &&
            headers[:content_range].to_s =~ /bytes \d+-(\d+)\/\d+/
            new_offset = $1.to_i + 1
          else
            new_offset = nil
            # Delete the "Byte range unsatisfiable" message
            body = nil if response_code == 416
          end

          # backward compatible with renaming soap log to cpi log
          if response_code == 204 && log_type == 'cpi'
            get_task_output(task_id, offset, 'soap')
          else
            [body, new_offset]
          end
        end

        def cancel_task(task_id)
          response_code, body = delete("/task/#{task_id}")
          raise AuthError if response_code == 401
          raise MissingTask, "No task##{task_id} found" if response_code == 404
          [body, response_code]
        end

        def create_backup
          request_and_track(:post, '/backups', {})
        end

        def fetch_backup
          _, path, _ = get('/backups', nil, nil, {}, :file => true)
          path
        end

        def list_locks
          get_json('/locks')
        end


        # Perform director HTTP request and track director task (if request
        # started one).
        # @param [Symbol] method HTTP method
        # @param [String] uri URI
        # @param [Hash] options Request and tracking options
        def request_and_track(method, uri, options = {})
          options = options.dup

          content_type = options.delete(:content_type)
          payload      = options.delete(:payload)
          track_opts   = options

          http_status, _, headers = request(method, uri, content_type, payload)
          location                = headers[:location]
          redirected              = [302, 303].include? http_status
          task_id                 = nil

          if redirected
            if location =~ /\/tasks\/(\d+)\/?$/ # Looks like we received task URI
              task_id = $1
              if @track_tasks
                tracker = Bosh::Cli::TaskTracking::TaskTracker.new(self, task_id, track_opts)
                status  = tracker.track
              else
                status = :running
              end
            else
              status = :non_trackable
            end
          else
            status = :failed
          end

          [status, task_id]
        end

        def upload_and_track(method, uri, filename, options = {})
          file = FileWithProgressBar.open(filename, 'r')
          request_and_track(method, uri, options.merge(:payload => file))
        ensure
          file.stop_progress_bar if file
        end

        def get_cloud_config
          _, cloud_configs = get_json_with_status('/cloud_configs?limit=1')
          latest = cloud_configs.first

          if !latest.nil?
            Bosh::Cli::CloudConfig.new(
              properties: latest["properties"],
              created_at: latest["created_at"])
          end
        end

        def update_cloud_config(cloud_config_yaml)
          status, _ = post('/cloud_configs', 'text/yaml', cloud_config_yaml)
          status == 201
        end

        def post(uri, content_type = nil, payload = nil, headers = {}, options = {})
          request(:post, uri, content_type, payload, headers, options)
        end

        def put(uri, content_type = nil, payload = nil, headers = {}, options = {})
          request(:put, uri, content_type, payload, headers, options)
        end

        def get(uri, content_type = nil, payload = nil, headers = {}, options = {})
          request(:get, uri, content_type, payload, headers, options)
        end

        def delete(uri, content_type = nil, payload = nil, headers = {}, options = {})
          request(:delete, uri, content_type, payload, headers, options)
        end

        private

        def director_name
          @director_name ||= get_status['name']
        end

        def releases_path(options = {})
          path = '/releases'
          params = [:rebase, :skip_if_exists].select { |p| options[p] }.map { |p| "#{p}=true" }
          path << "?#{params.join('&')}" unless params.empty?
          path
        end

        def stemcells_path(options = {})
          path = '/stemcells'
          path << "?fix=true" if options[:fix]
          path
        end

        def request(method, uri, content_type = nil, payload = nil, headers = {}, options = {})
          headers = headers.dup
          headers['Content-Type'] = content_type if content_type
          headers['Host'] = @director_uri.host

          tmp_file = nil
          response_reader = nil
          if options[:file]
            tmp_file = File.open(File.join(Dir.mktmpdir, 'streamed-response'), 'w')
            response_reader = lambda { |part| tmp_file.write(part) }
          end

          response = try_to_perform_http_request(
            method,
            "#{@scheme}://#{@director_ip}:#{@port}#{uri}",
            payload,
            headers,
            num_retries,
            retry_wait_interval,
            &response_reader
          )

          if options[:file]
            tmp_file.close
            body = tmp_file.path
          else
            body = response.body
          end

          if DIRECTOR_HTTP_ERROR_CODES.include?(response.code)
            if response.code == 404
              raise ResourceNotFound, parse_error_message(response.code, body, uri)
            else
              raise DirectorError, parse_error_message(response.code, body, uri)
            end
          end

          headers = response.headers.inject({}) do |hash, (k, v)|
            # Some HTTP clients symbolize headers, some do not.
            # To make it easier to switch between them, we try
            # to symbolize them ourselves.
            hash[k.to_s.downcase.gsub(/-/, '_').to_sym] = v
            hash
          end

          [response.code, body, headers]

        rescue SystemCallError => e
          raise DirectorError, "System call error while talking to director: #{e}"
        end

        def parse_error_message(status, body, uri)
          parsed_body = JSON.parse(body.to_s) rescue {}

          if parsed_body['code'] && parsed_body['description']
            'Error %s: %s' % [parsed_body['code'],
                              parsed_body['description']]
          elsif status == 404
            "The #{director_name} bosh director doesn't understand the following API call: #{uri}." +
              " The bosh deployment may need to be upgraded."
          else
            'HTTP %s: %s' % [status, body]
          end
        end

        def try_to_perform_http_request(method, uri, payload, headers, num_retries, retry_wait_interval, &response_reader)
          num_retries.downto(1) do |n|
            begin
              return perform_http_request(method, uri, payload, headers, &response_reader)

            rescue DirectorInaccessible
              warning("cannot access director, trying #{n-1} more times...") if n != 1
              raise if n == 1
              sleep(retry_wait_interval)
            end
          end
        end

        def generate_http_client
          @http_client ||= HTTPClient.new.tap do |http_client|
            http_client.send_timeout    = API_TIMEOUT
            http_client.receive_timeout = API_TIMEOUT
            http_client.connect_timeout = CONNECT_TIMEOUT
          end
        end

        def perform_http_request(method, uri, payload = nil, headers = {}, &block)
          http_client = generate_http_client

          if @ca_cert.nil?
            http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
            http_client.ssl_config.verify_callback = Proc.new {}
          else
            unless File.exists?(@ca_cert)
              err('Invalid ca certificate path')
            end

            parsed_url = nil
            begin
              parsed_url = URI.parse(uri)
            rescue => e
              err("Failed to parse director URL: #{e.message}")
            end

            unless parsed_url.instance_of?(URI::HTTPS)
              err('CA certificate cannot be used with HTTP protocol')
            end

            # pass in client certificate
            begin
              cert_store = OpenSSL::X509::Store.new
              cert_store.add_file(@ca_cert)
            rescue OpenSSL::X509::StoreError => e
              err("Invalid SSL Cert for '#{uri}': #{e.message}")
            end
            http_client.ssl_config.cert_store = cert_store
          end

          if @credentials
            headers['Authorization'] = @credentials.authorization_header
          end

          http_client.request(method, uri, {
            :body => payload,
            :header => headers,
          }, &block)

        rescue URI::Error,
               SocketError,
               Errno::ECONNREFUSED,
               Errno::ETIMEDOUT,
               Errno::ECONNRESET,
               Timeout::Error,
               HTTPClient::TimeoutError,
               HTTPClient::KeepAliveDisconnected,
               OpenSSL::SSL::SSLError,
               OpenSSL::X509::StoreError => e

          if e.is_a?(OpenSSL::SSL::SSLError) && e.message.include?('certificate verify failed')
            err("Invalid SSL Cert for '#{uri}': #{e.message}")
          end
          raise DirectorInaccessible, "cannot access director (#{e.message})"

        rescue HTTPClient::BadResponseError => e
          err("Received bad HTTP response from director: #{e}")

        # HTTPClient doesn't have a root exception but instead subclasses RuntimeError
        rescue RuntimeError => e
          say("Perform request #{method}, #{uri}, #{headers.inspect}, #{payload.inspect}")
          err("REST API call exception: #{e}")
        end

        def get_json(url)
          status, body = get_json_with_status(url)
          raise AuthError if status == 401
          raise DirectorError, "Director HTTP #{status}" if status != 200
          body
        end

        def get_json_with_status(url)
          status, body, _ = get(url, 'application/json')
          body = JSON.parse(body) if status == 200
          [status, body]
        rescue JSON::ParserError
          raise DirectorError, "Cannot parse director response: #{body}"
        end

        def add_query_string(url, parts)
          if parts.size > 0
            "#{url}?#{URI.encode_www_form(parts)}"
          else
            url
          end
        end

        attr_reader :num_retries, :retry_wait_interval
      end
    end
  end
end
