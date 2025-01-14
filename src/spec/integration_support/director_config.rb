require 'integration_support/constants'
require 'integration_support/uaa_service'

module IntegrationSupport
  class DirectorConfig
    attr_accessor :audit_log_path
    attr_reader :director_name,
                :agent_wait_timeout,
                :keep_unreachable_vms,
                :blobstore_storage_dir,
                :cloud_storage_dir,
                :config_server_cert_path,
                :config_server_enabled,
                :config_server_uaa_ca_cert_path,
                :config_server_uaa_client_id,
                :config_server_uaa_client_secret,
                :config_server_uaa_url,
                :config_server_url,
                :database,
                :database_ca_path,
                :default_update_vm_strategy,
                :director_fix_stateful_nodes,
                :director_ips,
                :director_ruby_port,
                :dns_enabled,
                :enable_cpi_resize_disk,
                :enable_cpi_update_disk,
                :enable_nats_delivered_templates,
                :enable_short_lived_nats_bootstrap_credentials,
                :enable_short_lived_nats_bootstrap_credentials_compilation_vms,
                :external_cpi_config,
                :generate_vm_passwords,
                :local_dns,
                :director_certificate_expiry_json_path,
                :nats_client_ca_certificate_path,
                :nats_client_ca_private_key_path,
                :nats_director_tls,
                :nats_port,
                :nats_server_ca_path,
                :networks,
                :remove_dev_tools,
                :sandbox_root,
                :trusted_certs,
                :uaa_url,
                :user_authentication,
                :users_in_manifest,
                :verify_multidigest_path,
                :preferred_cpi_api_version

    def initialize(attrs, port_provider)
      @director_name = 'TestDirector'
      @director_ruby_port = port_provider.get_port(:director_ruby)
      @nats_port = port_provider.get_port(:nats)

      @sandbox_root = attrs.fetch(:sandbox_root)

      @database = attrs.fetch(:database)
      @database_ca_path = IntegrationSupport::Constants::DATABASE_CA_PATH

      @blobstore_storage_dir = attrs.fetch(:blobstore_storage_dir)
      @verify_multidigest_path = attrs.fetch(:verify_multidigest_path)

      @director_fix_stateful_nodes = attrs.fetch(:director_fix_stateful_nodes, false)

      @dns_enabled = attrs.fetch(:dns_enabled, true)
      @local_dns = attrs.fetch(:local_dns,
                               'enabled' => false,
                               'include_index' => false,
                               'use_dns_addresses' => false)

      @networks = attrs.fetch(:networks, 'enable_cpi_management' => false)

      @external_cpi_config = attrs.fetch(:external_cpi_config)

      @cloud_storage_dir = attrs.fetch(:cloud_storage_dir)

      @user_authentication = attrs.fetch(:user_authentication)
      @uaa_url = "https://127.0.0.1:8443"

      @config_server_enabled = attrs.fetch(:config_server_enabled)
      @config_server_url = "https://127.0.0.1:#{port_provider.get_port(:config_server_port)}"
      @config_server_cert_path = IntegrationSupport::ConfigServerService::ROOT_CERT

      @config_server_uaa_url = @uaa_url
      @config_server_uaa_client_id = 'test'
      @config_server_uaa_client_secret = 'secret'
      @config_server_uaa_ca_cert_path = IntegrationSupport::UaaService::ROOT_CERT

      @trusted_certs = attrs.fetch(:trusted_certs)
      @users_in_manifest = attrs.fetch(:users_in_manifest, true)
      @enable_cpi_resize_disk = attrs.fetch(:enable_cpi_resize_disk, false)
      @enable_cpi_update_disk = attrs.fetch(:enable_cpi_update_disk, false)
      @default_update_vm_strategy = attrs.fetch(:default_update_vm_strategy, nil)
      @enable_nats_delivered_templates = attrs.fetch(:enable_nats_delivered_templates, false)
      @enable_short_lived_nats_bootstrap_credentials = attrs.fetch(:enable_short_lived_nats_bootstrap_credentials, false)
      @enable_short_lived_nats_bootstrap_credentials_compilation_vms = attrs.fetch(
        :enable_short_lived_nats_bootstrap_credentials_compilation_vms,
        false,
      )
      @generate_vm_passwords = attrs.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = attrs.fetch(:remove_dev_tools, false)
      @director_ips = attrs.fetch(:director_ips, [])
      @director_certificate_expiry_json_path = attrs.fetch(:director_certificate_expiry_json_path)
      @nats_server_ca_path = attrs.fetch(:nats_server_ca_path)
      @nats_client_ca_private_key_path = attrs.fetch(:nats_client_ca_private_key_path)
      @nats_client_ca_certificate_path = attrs.fetch(:nats_client_ca_certificate_path)
      @nats_director_tls = attrs.fetch(:nats_director_tls)
      @agent_wait_timeout = attrs.fetch(:agent_wait_timeout, 600)
      @preferred_cpi_api_version = attrs.fetch(:preferred_cpi_api_version)
      @keep_unreachable_vms = attrs.fetch(:keep_unreachable_vms, false)
    end

    def render(template_path)
      template_contents = File.read(template_path)
      template = ERB.new(template_contents)
      template.result(binding)
    end
  end
end
