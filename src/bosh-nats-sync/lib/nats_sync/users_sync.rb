require 'rest-client'
require 'base64'
require 'nats_sync/nats_auth_config'
require 'open3'

module NATSSync
  class UsersSync
    def initialize(nats_config_file_path, bosh_config, nats_server_executable, nats_server_pid_file)
      @nats_config_file_path = nats_config_file_path
      @bosh_config = bosh_config
      @nats_server_executable = nats_server_executable
      @nats_server_pid_file = nats_server_pid_file
    end

    def execute_users_sync
      NATSSync.logger.info 'Executing NATS Users Synchronization'
      vms_uuids = query_all_running_vms
      current_file_hash = nats_file_hash
      write_nats_config_file(vms_uuids, read_subject_file(@bosh_config['director_subject_file']),
                             read_subject_file(@bosh_config['hm_subject_file']))
      new_file_hash = nats_file_hash
      UsersSync.reload_nats_server_config(@nats_server_executable, @nats_server_pid_file) unless current_file_hash == new_file_hash
      NATSSync.logger.info 'Finishing NATS Users Synchronization'
      vms_uuids
    end

    def self.reload_nats_server_config(nats_server_executable, nats_server_pid_file)
      output, status = Open3.capture2e("#{nats_server_executable} --signal reload=#{nats_server_pid_file}")
      unless status.success?
        raise("Cannot execute: #{nats_server_executable} --signal reload=#{nats_server_pid_file}, Status Code: #{status} \nError: #{output}")
      end
    end

    private

    def read_subject_file(file_path)
      return nil unless File.exist?(file_path)
      return nil if File.empty?(file_path)

      File.read(file_path).strip
    end

    def nats_file_hash
      Digest::MD5.file(@nats_config_file_path).hexdigest
    end

    def call_bosh_api(endpoint)
      response = RestClient::Request.execute(
        url: @bosh_config['url'] + endpoint,
        method: :get,
        headers: { 'Authorization' => create_authentication_header },
        verify_ssl: false,
      )
      NATSSync.logger.debug(response.inspect)
      raise("Cannot access: #{endpoint}, Status Code: #{response.code}, #{response.body}") unless response.code == 200

      response.body
    end

    def query_all_deployments
      deployments_json = JSON.parse(call_bosh_api('/deployments'))
      deployments_json.map { |deployment| deployment['name'] }
    end

    def get_vms_by_deployment(deployment)
      virtual_machines = JSON.parse(call_bosh_api("/deployments/#{deployment}/vms"))
      virtual_machines.map { |virtual_machine| virtual_machine['agent_id'] }
    end

    def query_all_running_vms
      deployments = query_all_deployments
      vms_uuids = []
      deployments.each { |deployment| vms_uuids += get_vms_by_deployment(deployment) }
      vms_uuids
    end

    def call_bosh_api_no_auth(endpoint)
      response = RestClient::Request.execute(
        url: @bosh_config['url'] + endpoint,
        method: :get,
        verify_ssl: false,
      )
      NATSSync.logger.debug(response.inspect)
      raise("Cannot access: #{endpoint}, Status Code: #{response.code}, #{response.body}") unless response.code == 200

      response.body
    end

    def info
      body = call_bosh_api_no_auth('/info')

      JSON.parse(body)
    end

    def create_authentication_header
      NATSSync::AuthProvider.new(info, @bosh_config).auth_header
    end

    def write_nats_config_file(vms_uuids, director_subject, hm_subject)
      File.open(@nats_config_file_path, 'w') do |f|
        f.write(JSON.unparse(NatsAuthConfig.new(vms_uuids, director_subject, hm_subject).create_config))
      end
    end
  end
end
