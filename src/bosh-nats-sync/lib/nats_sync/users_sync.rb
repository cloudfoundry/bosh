require 'base64'
require 'net/http'
require 'openssl'
require 'open3'
require 'nats_sync/nats_auth_config'

module NATSSync
  class UsersSync
    HTTP_SUCCESS = "200"
    DEFAULT_DIRECTOR_CONNECTION_WAIT_TIMEOUT = 60
    DEFAULT_DIRECTOR_CONNECTION_RETRY_INTERVAL = 1

    DIRECTOR_CONNECTION_ERRORS = [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
    ].freeze

    def initialize(nats_config_file_path, bosh_config, nats_server_executable, nats_server_pid_file)
      @nats_config_file_path = nats_config_file_path
      @bosh_config = bosh_config
      @nats_server_executable = nats_server_executable
      @nats_server_pid_file = nats_server_pid_file
    end

    def execute_users_sync
      NATSSync.logger.info 'Executing NATS Users Synchronization'
      vms = []
      overwriteable_config_file = true
      begin
        wait_for_director_connection
        vms = query_all_running_vms
      rescue RuntimeError => e
        NATSSync.logger.error "Could not query all running vms: #{e.message}"
        overwriteable_config_file = user_file_overwritable?
        if overwriteable_config_file
          NATSSync.logger.info 'NATS config file is empty, writing basic users config file.'
        else
          NATSSync.logger.info 'NATS config file is not empty, doing nothing.'
        end
      end

      if overwriteable_config_file
        current_file_hash = nats_file_hash
        write_nats_config_file(vms, read_subject_file(@bosh_config['director_subject_file']),
                               read_subject_file(@bosh_config['hm_subject_file']))
        new_file_hash = nats_file_hash
        unless current_file_hash == new_file_hash
          UsersSync.reload_nats_server_config(@nats_server_executable,
                                              @nats_server_pid_file)
        end
      end
      NATSSync.logger.info 'Finishing NATS Users Synchronization'
    end

    def self.reload_nats_server_config(nats_server_executable, nats_server_pid_file)
      nats_command = "#{nats_server_executable} --signal reload=#{nats_server_pid_file}"

      output, status = Open3.capture2e(nats_command)

      unless status.success?
        raise("Cannot execute: #{nats_command}, Status Code: #{status}\nError: #{output}")
      end
    end

    private

    def wait_for_director_connection
      timeout = @bosh_config['connection_wait_timeout'] || DEFAULT_DIRECTOR_CONNECTION_WAIT_TIMEOUT
      max_attempts = (timeout / DEFAULT_DIRECTOR_CONNECTION_RETRY_INTERVAL).to_i
      max_attempts = 1 if max_attempts < 1

      Bosh::Common.retryable(
        sleep: DEFAULT_DIRECTOR_CONNECTION_RETRY_INTERVAL,
        tries: max_attempts,
        on: DIRECTOR_CONNECTION_ERRORS,
      ) do |attempt, exception|
        if exception
          NATSSync.logger.info("Waiting for director API to become available (attempt #{attempt}/#{max_attempts}): #{exception.message}")
        end
        # Make a lightweight request to verify director is reachable
        bosh_api_response_body('/info', auth: false)
        true
      end
    end

    def user_file_overwritable?
      JSON.parse(File.read(@nats_config_file_path)).empty?
    rescue RuntimeError, JSON::ParserError
      true
    end

    def read_subject_file(file_path)
      return nil unless File.exist?(file_path)
      return nil if File.empty?(file_path)

      File.read(file_path).strip
    end

    def nats_file_hash
      Digest::MD5.file(@nats_config_file_path).hexdigest
    end

    def parsed_uri_for(api_path:)
      URI.parse("#{@bosh_config['url']}#{api_path}")
    end

    def bosh_api_response_body(api_path, auth: true)
      parsed_uri = parsed_uri_for(api_path: api_path)

      response =
        Net::HTTP.new("#{parsed_uri.host}", parsed_uri.port).tap do |net_http|
          configure_tls(net_http: net_http, parsed_uri: parsed_uri)
        end.get(parsed_uri.request_uri, build_headers(auth: auth))

      NATSSync.logger.debug(response.inspect)
      unless response.code == HTTP_SUCCESS
        raise("Cannot access: #{api_path}, Status Code: #{response.code}, #{response.body}")
      end

      response.body
    end

    def configure_tls(net_http:, parsed_uri:)
      return unless parsed_uri.scheme == 'https'

      net_http.use_ssl = true
      net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ca_path = @bosh_config['ca_cert'].to_s
      if ca_path_valid?(ca_path)
        net_http.ca_file = ca_path
      end
    end

    def ca_path_valid?(path)
      return false if path.strip.empty?

      File.file?(path) && !File.zero?(path)
    rescue SystemCallError
      false
    end

    def query_all_deployments
      deployments_json = JSON.parse(bosh_api_response_body('/deployments'))
      deployments_json.map { |deployment| deployment['name'] }
    end

    def get_vms_by_deployment(deployment)
      JSON.parse(bosh_api_response_body("/deployments/#{deployment}/vms"))
    end

    def query_all_running_vms
      deployments = query_all_deployments
      vms = []
      deployments.each { |deployment| vms += get_vms_by_deployment(deployment) }
      vms
    end

    def info
      return @director_info if @director_info

      @director_info = JSON.parse(bosh_api_response_body('/info', auth: false))
    end

    def build_headers(auth: true)
      if auth
        auth_header = "#{NATSSync::AuthProvider.new(info, @bosh_config).auth_header}"
        NATSSync.logger.debug 'auth_header is empty, next REST call could fail' if auth_header.empty?

        { 'Authorization' => auth_header }
      else
        {}
      end
    end

    def write_nats_config_file(vms, director_subject, hm_subject)
      NATSSync.logger.debug 'Writing NATS config with the following users: ' + vms.to_s
      File.open(@nats_config_file_path, 'w') do |f|
        f.write(JSON.unparse(NatsAuthConfig.new(vms, director_subject, hm_subject).create_config))
      end
    end
  end
end
