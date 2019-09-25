require 'common/retryable'

module Bosh::Dev::Sandbox
  class ConfigServerService
    attr_reader :port

    CONFIG_SERVER_VERSION = '0.1.19'.freeze

    LOCAL_CONFIG_SERVER_FILE_NAME = "bosh-config-server-executable"

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-config-server')
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox/config_server', REPO_ROOT)

    # Keys and Certs
    CERTS_DIR = File.expand_path('certs', ASSETS_DIR)
    SERVER_CERT = File.join(CERTS_DIR, 'server.crt')
    SERVER_KEY = File.join(CERTS_DIR, 'server.key')
    NON_CA_SIGNED_CERT = File.join(CERTS_DIR, 'serverWithWrongCA.crt')
    NON_CA_SIGNED_CERT_KEY = File.join(CERTS_DIR, 'serverWithWrongCA.key')
    ROOT_CERT = File.join(CERTS_DIR, 'rootCA.pem')
    ROOT_PRIVATE_KEY = File.join(CERTS_DIR, 'rootCA.key')
    JWT_VERIFICATION_KEY = File.join(CERTS_DIR, 'jwtVerification.key')
    UAA_CA_CERT = File.join(CERTS_DIR, 'server.crt')

    def initialize(port_provider, base_log_path, logger, test_env_number)
      @port = port_provider.get_port(:config_server_port)
      @logger = logger
      @log_location = "#{base_log_path}.config-server.out"
      @config_server_config_file= File.join(INSTALL_DIR, "config-server-config#{test_env_number}.json")
      @config_server_socket_connector = SocketConnector.new('config-server', 'localhost', @port, @log_location, logger)

      @config_server_process = Bosh::Dev::Sandbox::Service.new(
        [executable_path, @config_server_config_file],
        {
          output: @log_location
        },
        @logger
      )
    end

    def self.install
      FileUtils.mkdir_p(INSTALL_DIR)
      downloaded_file_name = download(CONFIG_SERVER_VERSION)
      executable_file_path = File.join(INSTALL_DIR, LOCAL_CONFIG_SERVER_FILE_NAME)
      FileUtils.copy(File.join(INSTALL_DIR, downloaded_file_name), executable_file_path)
      File.chmod(0777, executable_file_path)
    end

    def start(with_trusted_certs)
      setup_config_file(with_trusted_certs)
      @config_server_process.start

      begin
        @config_server_socket_connector.try_to_connect(3000)
      rescue
        output_service_log(@config_server_process.description, @config_server_process.stdout_contents, @config_server_process.stderr_contents)
        raise
      end
    end

    def stop
      @config_server_process.stop
    end

    def restart(with_trusted_certs)
      @config_server_process.stop
      start(with_trusted_certs)
    end

    private

    def self.download(version)
      platform = RUBY_PLATFORM =~ /darwin/ ? 'darwin' : 'linux'

      file_name_to_download = "config-server-#{version}-#{platform}-amd64"

      retryable.retryer do
        destination_path = File.join(INSTALL_DIR, file_name_to_download)
        `#{File.dirname(__FILE__)}/install_binary.sh #{file_name_to_download} #{destination_path} '' config-server-releases`
        $? == 0
      end

      file_name_to_download
    end

    def self.retryable
      Bosh::Retryable.new({tries: 6})
    end

    def self.read_current_version
      file = File.open(File.join(INSTALL_DIR, 'current-version'), 'r')
      version = file.read
      file.close

      version
    end

    def executable_path
      File.join(INSTALL_DIR, LOCAL_CONFIG_SERVER_FILE_NAME)
    end

    def setup_config_file(with_trusted_certs = true)
      config = with_trusted_certs ? config_json : config_with_untrusted_cert_json
      File.open(@config_server_config_file, 'w') { |file| file.write(config) }
    end

    def config_json
      config = {
        port: @port,
        store: 'memory',
        private_key_file_path: SERVER_KEY,
        certificate_file_path: SERVER_CERT,
        jwt_verification_key_path: JWT_VERIFICATION_KEY,
        ca_certificate_file_path: ROOT_CERT,
        ca_private_key_file_path: ROOT_PRIVATE_KEY
      }
      JSON.dump(config)
    end

    def config_with_untrusted_cert_json
      config = {
        port: @port,
        store: 'memory',
        private_key_file_path: NON_CA_SIGNED_CERT_KEY,
        certificate_file_path: NON_CA_SIGNED_CERT,
        jwt_verification_key_path: JWT_VERIFICATION_KEY,
        ca_certificate_file_path: ROOT_CERT,
        ca_private_key_file_path: ROOT_PRIVATE_KEY
      }
      JSON.dump(config)
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
