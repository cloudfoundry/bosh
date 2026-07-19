require 'integration_support/constants'

module IntegrationSupport
  class NginxService

    CONFIG_TEMPLATE = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nginx.conf.erb')

    def self.install
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
        # The nginx package now uses spec.lock. Its package blob lives in the
        # public GCS blobstore alongside all other BOSH release blobs and contains
        # the nginx source tarballs plus the packaging script that compile() will run below.
        #
        # We download it directly via curl rather than going through
        # `bosh create-release --force`, which tries to resolve *all* release
        # packages and fails when any package has a fingerprint that differs from
        # what is indexed in .final_builds (e.g. packages with local source
        # changes like director, nats, davcli, health_monitor). We only need
        # the nginx package blob here, so the direct download is both simpler
        # and more reliable for local development.

        # If the packaging script is already present and matches the current
        # fingerprint, the blob was already extracted — skip re-downloading.
        cached_fingerprint_file = 'packages/nginx/.blob-fingerprint'
        if File.exist?('packages/nginx/packaging') &&
           File.exist?(cached_fingerprint_file) &&
           File.read(cached_fingerprint_file).strip == package_fingerprint
          puts 'nginx package blob already extracted, skipping download'
          return
        end

        index = YAML.load_file('.final_builds/packages/nginx/index.yml')
        blobstore_id = index.dig('builds', package_fingerprint, 'blobstore_id')
        raise "nginx fingerprint #{package_fingerprint} not found in .final_builds/packages/nginx/index.yml" unless blobstore_id

        blob_url = "https://storage.googleapis.com/bosh-release-blobs/#{blobstore_id}"
        run_command("curl -fSL -o /tmp/nginx-package.tgz '#{blob_url}'")
        run_command('tar -xf /tmp/nginx-package.tgz -C packages/nginx')
        File.write(cached_fingerprint_file, package_fingerprint)
      end
    end

    COMPILED_PLATFORM_FILE    = File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'platform')
    COMPILED_FINGERPRINT_FILE = File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'nginx-fingerprint')

    def should_compile?
      !File.file?(EXECUTABLE_PATH) || platform_has_changed? || fingerprint_has_changed?
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(WORK_DIR)

      FileUtils.mkdir_p(WORK_DIR)

      # Write the platform marker before compilation so platform_has_changed?
      # is accurate on the next run.
      FileUtils.mkdir_p(IntegrationSupport::Constants::INTEGRATION_BIN_DIR)
      File.write(COMPILED_PLATFORM_FILE, RUBY_PLATFORM)

      # Make sure packaging script has its own blob copies so that blobs/ directory is not affected
      nginx_blobs_path = File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'packages', 'nginx')
      run_command("cp -R #{nginx_blobs_path}/. #{WORK_DIR}")

      Dir.chdir(WORK_DIR) do
        packaging_script_path = File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'packages', 'nginx', 'packaging')
        run_command("bash #{packaging_script_path}", { 'BOSH_INSTALL_TARGET' => IntegrationSupport::Constants::INTEGRATION_BIN_DIR })
      end

      # Record the fingerprint of what we just compiled so fingerprint_has_changed?
      # can skip recompilation on subsequent runs when nothing has changed.
      File.write(COMPILED_FINGERPRINT_FILE, package_fingerprint)
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

    def platform_has_changed?
      return true unless File.exist?(COMPILED_PLATFORM_FILE)
      File.read(COMPILED_PLATFORM_FILE).strip != RUBY_PLATFORM
    end

    def fingerprint_has_changed?
      return true unless File.exist?(COMPILED_FINGERPRINT_FILE)
      File.read(COMPILED_FINGERPRINT_FILE).strip != package_fingerprint
    end

    def package_fingerprint
      require 'yaml'
      YAML.load_file(File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'packages', 'nginx', 'spec.lock'))['fingerprint']
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
