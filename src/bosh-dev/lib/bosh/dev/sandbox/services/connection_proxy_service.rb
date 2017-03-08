require 'bosh/dev/sandbox/workspace'

module Bosh::Dev::Sandbox
  class ConnectionProxyService
    def initialize(sandbox_root, forward_to_host, forward_to_port, listen_port, base_log_path, logger)
      @logger = logger
      log_path = "#{base_log_path}.tcp_proxy_nginx.out"

      config_path = File.join(sandbox_root, 'nginx_tcp_proxy.conf')
      nginx = TCPProxyNginx.new
      cmd = %W[#{nginx.executable_path} -c #{config_path}]
      @process = Service.new(cmd, {output: log_path}, logger)
      @socket_connector = SocketConnector.new('tcp_proxy_nginx', 'localhost', listen_port, 'unknown', logger)

      attrs = {
        sandbox_root: sandbox_root,
        nginx_port: listen_port,
        database_port: forward_to_port,
        database_host: forward_to_host,
      }
      template_path = Workspace.new.asset_path('nginx_tcp_proxy.conf.erb')

      @config = TCPProxyNginxConfig.new(template_path, config_path, attrs)
      @config.write
    end

    def start
      @process.start
      @socket_connector.try_to_connect
    end

    def stop
      @process.stop
    end
  end

  class TCPProxyNginx
    def initialize
      @workspace = Workspace.new
      @install_dir = @workspace.repo_path(File.join('tmp', 'integration-tcp-proxy-nginx'))
    end

    def executable_path
      File.join(@install_dir, 'sbin', 'nginx')
    end

    def install
      return if File.exists?(executable_path)

      FileUtils.rm_rf(@install_dir)
      FileUtils.mkdir_p(@install_dir)

      Dir.mktmpdir do |working_dir|
        runner = Bosh::Core::Shell.new
        tcp_proxy_source_dir = @workspace.asset_path('tcp_proxy_nginx')
        FileUtils.cp_r(tcp_proxy_source_dir, working_dir)

        Dir.chdir(File.join(working_dir, 'tcp_proxy_nginx')) do
          runner.run('bash ./install.sh', env: {
              'BOSH_INSTALL_TARGET' => @install_dir,
            })
        end
      end
    end
  end

  class TCPProxyNginxConfig
    attr_reader :sandbox_root, :nginx_port, :database_port, :database_host

    def initialize(template, result_path, attrs)
      @template = template
      @result_path = result_path

      @sandbox_root = attrs.fetch(:sandbox_root)
      @nginx_port = attrs.fetch(:nginx_port)
      @database_port = attrs.fetch(:database_port)
      @database_host = attrs.fetch(:database_host)
    end

    def write
      template_contents = File.read(@template)
      template = ERB.new(template_contents)
      contents = template.result(binding)
      File.open(@result_path, 'w+') { |f| f.write(contents) }
    end
  end
end
