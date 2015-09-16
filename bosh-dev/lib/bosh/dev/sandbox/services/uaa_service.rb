module Bosh::Dev::Sandbox
  class UaaService
    attr_reader :port

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join(REPO_ROOT, 'tmp', 'integration-uaa')
    TOMCAT_DIR = File.join(INSTALL_DIR, 'apache-tomcat-8.0.21')

    def initialize(port_provider, base_log_path, logger)
      @port = port_provider.get_port(:uaa_http)
      @server_port = port_provider.get_port(:uaa_server)

      @logger = logger
      @build_mutex = Mutex.new
      @log_location = "#{base_log_path}.uaa.out"

      @uaa_socket_connector = SocketConnector.new('uaa', 'localhost', @port, @log_location, logger)
    end

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

    def start
      uaa_process.start

      begin
        @uaa_socket_connector.try_to_connect(3000)
      rescue
        output_service_log(uaa_process.description, uaa_process.stdout_contents, uaa_process.stderr_contents)
        raise
      end
    end

    def stop
      uaa_process.stop
    end

    def reconfigure(encryption)
      @encryption = encryption
    end

    private

    def uaa_process
      return @uaa_process if @uaa_process

      opts = {
          'uaa.http_port' => @port,
          'uaa.server_port' => @server_port,
          'uaa.access_log_dir' => File.dirname(@log_location),
      }

      @service = Service.new(
          [executable_path, 'run', '-config', server_xml],
          {
              output: @log_location,
              env: {
                  'CATALINA_OPTS' => opts.map { |k, v| "-D#{k}=#{v}" }.join(" "),
                  'UAA_CONFIG_PATH' => config_path
              }
          },
          @logger
      )

    end

    def working_dir
      File.expand_path('spec/assets/uaa', REPO_ROOT)
    end

    def executable_path
      File.join(TOMCAT_DIR, 'bin', 'catalina.sh')
    end

    def server_xml
      File.join(REPO_ROOT, 'bosh-dev', 'assets', 'sandbox', 'tomcat-server.xml')
    end

    def config_path
      base_path = 'spec/assets/uaa_config'
      if @encryption == 'asymmetric'
        return File.expand_path(File.join(base_path, 'asymmetric'), REPO_ROOT)
      end

      File.expand_path(File.join(base_path, 'symmetric'), REPO_ROOT)
    end

    DEBUG_HEADER = '*' * 20

    def output_service_log(description, stdout_contents, stderr_contents)
      @logger.error("#{DEBUG_HEADER} start #{description} stdout #{DEBUG_HEADER}")
      @logger.error(stdout_contents)
      @logger.error("#{DEBUG_HEADER} end #{description} stdout #{DEBUG_HEADER}")

      @logger.error("#{DEBUG_HEADER} start #{description} stderr #{DEBUG_HEADER}")
      @logger.error(stderr_contents)
      @logger.error("#{DEBUG_HEADER} end #{description} stderr #{DEBUG_HEADER}")
    end
  end
end
