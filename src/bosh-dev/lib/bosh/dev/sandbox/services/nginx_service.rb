module Bosh::Dev::Sandbox
  class NginxService
    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)
    NGINX_CONF_TEMPLATE = File.join(ASSETS_DIR, 'nginx.conf.erb')
    NGINX_CERT_DIR = File.join(ASSETS_DIR, 'ca', 'certs')

    def initialize(sandbox_root, port, director_ruby_port, uaa_port, logger)
      @logger = logger
      nginx = Nginx.new
      config_path = File.join(sandbox_root, 'nginx.conf')
      @process = Service.new(%W[#{nginx.executable_path} -c #{config_path}], {}, logger)
      @socket_connector = SocketConnector.new('director_nginx', 'localhost', port, 'unknown', logger)

      default_attrs = {
        ssl_cert_path: File.join(NGINX_CERT_DIR, 'server.crt'),
        ssl_cert_key_path: File.join(NGINX_CERT_DIR, 'server.key'),
        sandbox_root: sandbox_root,
        director_ruby_port: director_ruby_port,
        nginx_port: port,
        uaa_port: uaa_port,
      }
      @config = NginxConfig.new(NGINX_CONF_TEMPLATE, config_path, default_attrs)
      @config.write
    end

    def start
      @process.start
      @socket_connector.try_to_connect
    end

    def stop
      @process.stop
    end

    def restart_if_needed
      if @requires_restart
        stop
        start
      end
    end

    def reconfigure(ssl_mode)
      @requires_restart = @ssl_mode != ssl_mode
      @ssl_mode = ssl_mode

      if @ssl_mode == 'wrong-ca'
        ssl_cert_path =  File.join(NGINX_CERT_DIR, 'serverWithWrongCA.crt')
        ssl_cert_key_path =  File.join(NGINX_CERT_DIR, 'serverWithWrongCA.key')
      else
        ssl_cert_path =  File.join(NGINX_CERT_DIR, 'server.crt')
        ssl_cert_key_path =  File.join(NGINX_CERT_DIR, 'server.key')
      end

      @config.write(ssl_cert_path: ssl_cert_path, ssl_cert_key_path: ssl_cert_key_path)
    end
  end

  private

  class NginxConfig
    attr_reader :ssl_cert_path,
      :ssl_cert_key_path,
      :sandbox_root,
      :nginx_port,
      :director_ruby_port,
      :uaa_port

    def initialize(template, result_path, default_attrs)
      @template = template
      @result_path = result_path
      @default_attrs = default_attrs
    end

    def write(attrs = {})
      update_attr(attrs)
      template_contents = File.read(@template)
      template = ERB.new(template_contents)
      contents = template.result(binding)
      File.open(@result_path, 'w+') { |f| f.write(contents) }
    end

    private

    def update_attr(attrs)
      @ssl_cert_path = attrs.fetch(:ssl_cert_path, @default_attrs[:ssl_cert_path])
      @ssl_cert_key_path = attrs.fetch(:ssl_cert_key_path, @default_attrs[:ssl_cert_key_path])

      @sandbox_root = attrs.fetch(:sandbox_root, @default_attrs[:sandbox_root])
      @director_ruby_port = attrs.fetch(:director_ruby_port, @default_attrs[:director_ruby_port])
      @nginx_port = attrs.fetch(:director_port, @default_attrs[:nginx_port])
      @uaa_port = attrs.fetch(:uaa_port, @default_attrs[:uaa_port])
    end
  end
end
