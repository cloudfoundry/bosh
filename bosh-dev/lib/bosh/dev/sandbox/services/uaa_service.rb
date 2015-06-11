module Bosh::Dev::Sandbox
  class UaaService
    attr_reader :port

    def initialize(port_provider, base_log_path, repo_root, logger)
      @port = port_provider.get_port(:uaa)
      @repo_root = repo_root
      @logger = logger
      @build_mutex = Mutex.new

      uaa_ports = {
        'cargo.servlet.port' => @port,
        'cargo.tomcat.ajp.port' => port_provider.get_port(:uaa_tomcat),
        'cargo.rmi.port' => port_provider.get_port(:uaa_rmi)
      }

      arguments = uaa_ports.map { |pair| "-D#{pair.join('=')}" }
      arguments << %W(-P cargo.port=#{@port})

      log_location = "#{base_log_path}.uaa.out"
      timeout_arg = '-P cargo.local.timeout=300000'
      @uaa_process = Service.new(
        ['./gradlew', arguments, timeout_arg, 'run',  '--stacktrace'].flatten,
        {
          output: log_location,
          working_dir: working_dir,
          env: { 'UAA_CONFIG_PATH' => File.expand_path('spec/assets', @repo_root) }
        },
        logger,
      )

      @uaa_socket_connector = SocketConnector.new('uaa', 'localhost', @port, log_location, logger)
    end

    def start
      build

      @uaa_process.start

      begin
        @uaa_socket_connector.try_to_connect(3000)
      rescue
        output_service_log(@uaa_process.description, @uaa_process.stdout_contents, @uaa_process.stderr_contents)
        raise
      end
    end

    def stop
      @uaa_process.stop
    end

    private

    def working_dir
      File.expand_path('spec/assets/uaa', @repo_root)
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

    def build
      @build_mutex.synchronize do
        unless @built
          stdout, stderr, status = Open3.capture3('./gradlew build -x test', chdir: working_dir)
          unless status.success?
            output_service_log('building uaa', stdout, stderr)
            raise 'Failed to build Uaa'
          end
          @built = true
        end
      end
    end
  end
end
