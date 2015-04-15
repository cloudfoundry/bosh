require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Uaa
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join(REPO_ROOT, 'tmp', 'integration-uaa')
    TOMCAT_DIR =  File.join(INSTALL_DIR, 'apache-tomcat-8.0.21')
    RELEASE_ROOT = File.join(REPO_ROOT, 'release')
    UAA_CONFIG_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    def self.install
      FileUtils.rm_rf(INSTALL_DIR)
      FileUtils.mkdir_p(INSTALL_DIR)

      tomcat_url = 'https://s3.amazonaws.com/bosh-dependencies/apache-tomcat-8.0.21.tar.gz'
      out = `curl -L #{tomcat_url} | (cd #{INSTALL_DIR} && tar xfz -)`
      raise out unless $? == 0

      uaa_url = 'https://s3.amazonaws.com/bosh-dependencies/cloudfoundry-identity-uaa-2.0.3.war'
      webapp_path = File.join(TOMCAT_DIR, 'webapps', 'uaa.war')
      out = `curl --output #{webapp_path} -L #{uaa_url}`
      raise out unless $? == 0
    end

    def initialize(http_port, server_port, log_base, logger, runner = Bosh::Core::Shell.new)
      @http_port = http_port
      @server_port = server_port
      @log_base = log_base
      @logger = logger
      @runner = runner
    end

    attr_reader :service

    def start
      server_xml = File.join(UAA_CONFIG_DIR, 'tomcat-server.xml')
      log_path = "#{@log_base}.uaa.out"
      opts = {
        "uaa.http_port" => @http_port,
        "uaa.server_port" => @server_port,
        "uaa.access_log_dir" => File.dirname(log_path),
      }
      @service = Service.new([executable_path, 'run', '-config', server_xml],
        {
          output: log_path,
          env: {
            'CATALINA_OPTS' => opts.map {|k,v| "-D#{k}=#{v}"}.join(" "),
            'UAA_CONFIG_PATH' => UAA_CONFIG_DIR
          }
        },
        @logger,
      )

      @uaa_socket_connector = SocketConnector.new('uaa', '127.0.0.1', @http_port, @logger)

      @service.start
    end

    def await
      @uaa_socket_connector.try_to_connect(1000)
    end

    def stop
      @service.stop if @service
    end

    private

    def executable_path
      File.join(TOMCAT_DIR, 'bin', 'catalina.sh')
    end
  end
end
