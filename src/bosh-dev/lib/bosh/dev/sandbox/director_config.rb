module Bosh::Dev::Sandbox
  class DirectorConfig
    attr_reader :director_name,
      :director_ruby_port,
      :nats_port,
      :sandbox_root,
      :blobstore_storage_dir,
      :verify_multidigest_path,
      :external_cpi_config,
      :database,
      :director_fix_stateful_nodes,
      :dns_enabled,
      :local_dns,
      :cloud_storage_dir,
      :config_server_enabled,
      :config_server_url,
      :config_server_cert_path,
      :config_server_uaa_url,
      :config_server_uaa_client_id,
      :config_server_uaa_client_secret,
      :config_server_uaa_ca_cert_path,
      :user_authentication,
      :uaa_url,
      :trusted_certs,
      :users_in_manifest,
      :enable_post_deploy,
      :enable_nats_delivered_templates,
      :enable_cpi_resize_disk,
      :generate_vm_passwords,
      :remove_dev_tools,
      :director_ips,
      :nats_server_ca_path,
      :nats_client_ca_private_key_path,
      :nats_client_ca_certificate_path,
      :nats_director_tls

    def initialize(attrs, port_provider)
      @director_name = 'TestDirector'
      @director_ruby_port = port_provider.get_port(:director_ruby)
      @nats_port = port_provider.get_port(:nats)

      @sandbox_root = attrs.fetch(:sandbox_root)

      @database = attrs.fetch(:database)

      @blobstore_storage_dir = attrs.fetch(:blobstore_storage_dir)
      @verify_multidigest_path = attrs.fetch(:verify_multidigest_path)

      @director_fix_stateful_nodes = attrs.fetch(:director_fix_stateful_nodes, false)

      @dns_enabled = attrs.fetch(:dns_enabled, true)
      @local_dns = attrs.fetch(:local_dns, {'enabled' => false, 'include_index' => false, 'use_dns_addresses' => false})

      @external_cpi_config = attrs.fetch(:external_cpi_config)

      @cloud_storage_dir = attrs.fetch(:cloud_storage_dir)

      @user_authentication = attrs.fetch(:user_authentication)
      @uaa_url = "https://127.0.0.1:#{port_provider.get_port(:nginx)}/uaa"

      @config_server_enabled = attrs.fetch(:config_server_enabled)
      @config_server_url = "https://127.0.0.1:#{port_provider.get_port(:config_server_port)}"
      @config_server_cert_path = Bosh::Dev::Sandbox::ConfigServerService::ROOT_CERT

      @config_server_uaa_url = @uaa_url
      @config_server_uaa_client_id = 'test'
      @config_server_uaa_client_secret = 'secret'
      @config_server_uaa_ca_cert_path = Bosh::Dev::Sandbox::UaaService::ROOT_CERT

      @trusted_certs = attrs.fetch(:trusted_certs)
      @users_in_manifest = attrs.fetch(:users_in_manifest, true)
      @enable_post_deploy = attrs.fetch(:enable_post_deploy, false)
      @enable_cpi_resize_disk = attrs.fetch(:enable_cpi_resize_disk, false)
      @enable_nats_delivered_templates = attrs.fetch(:enable_nats_delivered_templates, false)
      @generate_vm_passwords = attrs.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = attrs.fetch(:remove_dev_tools, false)
      @director_ips = attrs.fetch(:director_ips, [])
      @nats_server_ca_path = attrs.fetch(:nats_server_ca_path)
      @nats_client_ca_private_key_path = attrs.fetch(:nats_client_ca_private_key_path)
      @nats_client_ca_certificate_path = attrs.fetch(:nats_client_ca_certificate_path)
      @nats_director_tls = attrs.fetch(:nats_director_tls)
    end

    def render(template_path)
      template_contents = File.read(template_path)
      template = ERB.new(template_contents)
      template.result(binding)
    end
  end
end
