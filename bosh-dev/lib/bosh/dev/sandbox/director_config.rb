module Bosh::Dev::Sandbox
  class DirectorConfig
    attr_reader :director_ruby_port,
      :nats_port,
      :sandbox_root,
      :blobstore_storage_dir,
      :external_cpi_enabled,
      :external_cpi_config,
      :database,
      :director_fix_stateful_nodes,
      :cloud_storage_dir,
      :user_authentication,
      :uaa_url,
      :trusted_certs,
      :users_in_manifest,
      :enable_post_deploy,
      :generate_vm_passwords,
      :remove_dev_tools

    def initialize(attrs, port_provider)
      @director_ruby_port = port_provider.get_port(:director_ruby)
      @nats_port = port_provider.get_port(:nats)

      @sandbox_root = attrs.fetch(:sandbox_root)

      @database = attrs.fetch(:database)

      @blobstore_storage_dir = attrs.fetch(:blobstore_storage_dir)

      @director_fix_stateful_nodes = attrs.fetch(:director_fix_stateful_nodes, false)

      @external_cpi_enabled = attrs.fetch(:external_cpi_enabled, false)
      @external_cpi_config = attrs.fetch(:external_cpi_config)

      @cloud_storage_dir = attrs.fetch(:cloud_storage_dir)

      @user_authentication = attrs.fetch(:user_authentication)
      @uaa_url = "https://127.0.0.1:#{port_provider.get_port(:nginx)}/uaa"

      @trusted_certs = attrs.fetch(:trusted_certs)
      @users_in_manifest = attrs.fetch(:users_in_manifest, true)
      @enable_post_deploy = attrs.fetch(:enable_post_deploy, false)
      @generate_vm_passwords = attrs.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = attrs.fetch(:remove_dev_tools, false)
    end

    def render(template_path)
      template_contents = File.read(template_path)
      template = ERB.new(template_contents)
      template.result(binding)
    end
  end
end
