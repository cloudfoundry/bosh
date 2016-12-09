require 'common/retryable'

module Bosh::Dev::Sandbox
  class UaaService
    attr_reader :port

    TOMCAT_VERSIONED_FILENAME = 'apache-tomcat-8.0.21'
    UAA_FILENAME = 'uaa.war'

    UAA_VERSION = 'cloudfoundry-identity-uaa-3.5.0'

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-uaa', UAA_VERSION)
    TOMCAT_DIR = File.join(INSTALL_DIR, TOMCAT_VERSIONED_FILENAME)

    # Keys and Certs
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox/ca', REPO_ROOT)
    CERTS_DIR = File.expand_path('certs', ASSETS_DIR)
    ROOT_CERT = File.join(CERTS_DIR, 'rootCA.pem')

    def initialize(port_provider, base_log_path, logger)
      @port = port_provider.get_port(:uaa_http)
      @server_port = port_provider.get_port(:uaa_server)

      @logger = logger
      @build_mutex = Mutex.new
      @log_location = "#{base_log_path}.uaa.out"

      @uaa_socket_connector = SocketConnector.new('uaa', 'localhost', @port, @log_location, logger)
    end

    def self.install
      webapp_path = File.join(TOMCAT_DIR, 'webapps', UAA_FILENAME)

      FileUtils.mkdir_p(TOMCAT_DIR)

      retryable.retryer do
        `#{File.dirname(__FILE__)}/install_tomcat.sh #{INSTALL_DIR} #{TOMCAT_VERSIONED_FILENAME} 957e88df8a9c3fc6b786321c4014b44c5c775773`
        $? == 0
      end

      retryable.retryer do
        `#{File.dirname(__FILE__)}/install_binary.sh #{UAA_VERSION}.war #{webapp_path} 6167d1b5afe3e12c26482fcb45c0056475cb3e1b9ca2996707d9ac9c22f60dc9 bosh-dependencies`
        $? == 0
      end
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

    def self.retryable
      Bosh::Retryable.new({tries: 6})
    end

    def uaa_process
      @service.stop if @service

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
