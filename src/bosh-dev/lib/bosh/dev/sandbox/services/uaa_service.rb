require 'common/retryable'

module Bosh::Dev::Sandbox
  class UaaService
    attr_reader :port

    TOMCAT_VERSIONED_FILENAME = 'apache-tomcat-8.0.21'.freeze
    UAA_FILENAME = 'uaa.war'.freeze

    UAA_VERSION = 'cloudfoundry-identity-uaa-3.5.0'.freeze

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-uaa', UAA_VERSION)
    TOMCAT_DIR = File.join(INSTALL_DIR, TOMCAT_VERSIONED_FILENAME)

    WAR_FILE_PATH = File.join(REPO_ROOT, TOMCAT_DIR, 'webapps', UAA_FILENAME)
    # Keys and Certs
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox/ca', REPO_ROOT)
    CERTS_DIR = File.expand_path('certs', ASSETS_DIR)
    ROOT_CERT = File.join(CERTS_DIR, 'rootCA.pem')

    def initialize(port_provider, sandbox_root, base_log_path, logger)
      @port = port_provider.get_port(:uaa_http)
      @server_port = port_provider.get_port(:uaa_server)

      @logger = logger
      @build_mutex = Mutex.new
      @log_location = "#{base_log_path}.uaa.out"

      @connector = HTTPEndpointConnector.new('uaa', 'localhost', @port, '/uaa/login', 'Reset password', @log_location, logger)

      @uaa_webapps_path = File.join(sandbox_root, 'uaa.webapps')
      unless File.exist? @uaa_webapps_path
        FileUtils.mkdir_p @uaa_webapps_path
        FileUtils.cp WAR_FILE_PATH, @uaa_webapps_path
      end

      @config_path = File.join(sandbox_root, 'uaa_config')
      FileUtils.mkdir_p(@config_path)
      write_config_path

      @uaa_process = initialize_uaa_process
    end

    def self.install
      FileUtils.mkdir_p(TOMCAT_DIR)

      retryable.retryer do
        `#{File.dirname(__FILE__)}/install_tomcat.sh #{INSTALL_DIR} #{TOMCAT_VERSIONED_FILENAME} 957e88df8a9c3fc6b786321c4014b44c5c775773`
        $? == 0
      end

      retryable.retryer do
        `#{File.dirname(__FILE__)}/install_binary.sh #{UAA_VERSION}.war #{WAR_FILE_PATH} 6167d1b5afe3e12c26482fcb45c0056475cb3e1b9ca2996707d9ac9c22f60dc9 bosh-dependencies`
        $? == 0
      end
    end

    def self.retryable
      Bosh::Retryable.new(tries: 6)
    end

    def start
      @uaa_process.start

      begin
        @connector.try_to_connect(6000)
      rescue StandardError
        output_service_log(@uaa_process.description, @uaa_process.stdout_contents, @uaa_process.stderr_contents)
        raise
      end
      @running_mode = @current_uaa_config_mode
    end

    def stop
      @uaa_process.stop
      @running_mode = 'stopped'
    end

    private

    def initialize_uaa_process
      opts = {
        'uaa.http_port' => @port,
        'uaa.server_port' => @server_port,
        'uaa.access_log_dir' => File.dirname(@log_location),
        'uaa.webapps' => @uaa_webapps_path,
        'securerandom.source' => 'file:/dev/urandom',
      }

      catalina_opts = ' -Xms512M -Xmx512M '
      catalina_opts += opts.map { |key, value| "-D#{key}=#{value}" }.join(' ')

      Service.new(
        [executable_path, 'run', '-config', server_xml],
        {
          output: @log_location,
          env: {
            'CATALINA_OPTS' => catalina_opts,
            'UAA_CONFIG_PATH' => @config_path,
          },
        },
        @logger,
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

    def write_config_path
      spec_assets_base_path = 'spec/assets/uaa_config'

      FileUtils.cp(
        File.expand_path(File.join(spec_assets_base_path, 'asymmetric', 'uaa.yml'), REPO_ROOT),
        @config_path,
      )
      @current_uaa_config_mode = 'asymmetric'
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
