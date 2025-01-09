require 'integration_support/constants'

module IntegrationSupport
  class NginxService

    CONFIG_TEMPLATE = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nginx.conf.erb')

    def self.install
      return if File.exist?(NginxInstaller::EXECUTABLE_PATH)

      installer = NginxInstaller.new
      installer.prepare

      if installer.should_compile?
        installer.compile
      else
        puts 'Skipping compiling nginx because shasums and platform have not changed'
      end
    end

    def initialize(sandbox_root, nginx_port, director_ruby_port, uaa_port, base_log_path, logger)
      @process =
        Service.new(
          %W[#{NginxInstaller::EXECUTABLE_PATH} -c #{File.join(sandbox_root, 'nginx.conf')} -p #{sandbox_root}],
          { output: logfile_path(base_log_path) },
          logger,
        )

      @socket_connector =
        SocketConnector.new(
          'director_nginx',
          'localhost',
          nginx_port,
          logfile_path(base_log_path),
          logger,
        )

      @config =
        NginxConfig.new(
          CONFIG_TEMPLATE,
          File.join(sandbox_root, 'nginx.conf'),
          {
            sandbox_root: sandbox_root,
            director_ruby_port: director_ruby_port,
            uaa_port: uaa_port,
            nginx_port: nginx_port,
            ssl_cert_path: File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.crt'),
            ssl_cert_key_path: File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.key'),
          },
        )

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
        ssl_cert_path =  File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'serverWithWrongCA.crt')
        ssl_cert_key_path =  File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'serverWithWrongCA.key')
      else
        ssl_cert_path =  File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.crt')
        ssl_cert_key_path =  File.join(IntegrationSupport::Constants::SANDBOX_CERTS_DIR, 'server.key')
      end

      @config.write(ssl_cert_path: ssl_cert_path, ssl_cert_key_path: ssl_cert_key_path)
    end

    private

    def logfile_path(base_log_path)
      "#{base_log_path}.nginx.out"
    end
  end

  class NginxInstaller
    WORK_DIR = File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_TMP_DIR, 'nginx-work')
    EXECUTABLE_PATH = File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'sbin', 'nginx')

    def prepare
      Dir.chdir(IntegrationSupport::Constants::BOSH_REPO_ROOT) do
        run_command('bosh sync-blobs')
        run_command('bosh create-release --force --tarball /tmp/release.tgz')
        nginx_package_path = run_command('tar -tvf /tmp/release.tgz --wildcards "*nginx.tgz" | cut -d" " -f 8')
        run_command("tar -zxvf /tmp/release.tgz -C /tmp #{nginx_package_path}")
        run_command('tar -zxvf /tmp/packages/nginx.tgz  -C packages/nginx')
      end
    end

    def should_compile?
      !File.file?(EXECUTABLE_PATH) || blob_has_changed? || platform_has_changed?
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(WORK_DIR)

      FileUtils.mkdir_p(WORK_DIR)

      run_command("echo '#{RUBY_PLATFORM}' > #{IntegrationSupport::Constants::INTEGRATION_BIN_DIR}/platform")

      # Make sure packaging script has its own blob copies so that blobs/ directory is not affected
      nginx_blobs_path = File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'packages', 'nginx')
      run_command("cp -R #{nginx_blobs_path}/. #{WORK_DIR}")

      Dir.chdir(WORK_DIR) do
        packaging_script_path = File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'packages', 'nginx', 'packaging')
        run_command("bash #{packaging_script_path}", { 'BOSH_INSTALL_TARGET' => IntegrationSupport::Constants::INTEGRATION_BIN_DIR })
      end
    end

    private

    def run_command(command, environment = {})
      command = [environment, 'bash', '-c', command]
      puts "Running: #{command.join(' ')}"

      io = IO.popen(command)

      lines =
        io.each_with_object("") do |line, collect|
          collect << line
          puts line.chomp
        end

      io.close
      process_status = $?

      raise "Command: #{command.inspect} failed with #{process_status.inspect}" unless process_status&.success?

      lines
    end

    def blob_has_changed?
      blobs_shasum = shasum(File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'blobs', 'nginx'))
      sandbox_copy_shasum = shasum(File.join(WORK_DIR, 'nginx'))

      blobs_shasum.sort != sandbox_copy_shasum.sort
    end

    def platform_has_changed?
      output = run_command("cat #{IntegrationSupport::Constants::INTEGRATION_BIN_DIR}/platform || true")
      output != RUBY_PLATFORM
    end

    def shasum(directory)
      output = run_command("find #{directory} \\! -type d -print0 | xargs -0 shasum -a 256")
      output.split("\n").map do |line|
        line.split(' ').first
      end
    end
  end

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
