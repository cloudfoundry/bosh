require 'bosh/dev/shell'

module Bosh::Dev::Sandbox
  class NginxService

    CONFIG_TEMPLATE = File.join(Bosh::Dev::ASSETS_DIR, 'nginx.conf.erb')
    CERTS_DIR = File.join(Bosh::Dev::ASSETS_DIR, 'ca', 'certs')

    def self.install
      installer = NginxInstaller.new(runner: Bosh::Dev::Shell.new)
      installer.prepare

      if installer.should_compile?
        installer.compile
      else
        puts 'Skipping compiling nginx because shasums and platform have not changed'
      end
    end

    def initialize(sandbox_root, port, director_ruby_port, uaa_port, base_log_path, logger)
      @logger = logger
      log_path = "#{base_log_path}.nginx.out"
      @process =
        Service.new(%W[#{NginxInstaller::EXECUTABLE_PATH} -c #{File.join(sandbox_root, 'nginx.conf')} -p #{sandbox_root}],
                    { output: log_path }, @logger)
      @socket_connector = SocketConnector.new('director_nginx', 'localhost', port, log_path, @logger)

      default_attrs = {
        ssl_cert_path: File.join(CERTS_DIR, 'server.crt'),
        ssl_cert_key_path: File.join(CERTS_DIR, 'server.key'),
        sandbox_root: sandbox_root,
        director_ruby_port: director_ruby_port,
        nginx_port: port,
        uaa_port: uaa_port,
      }
      @config = NginxConfig.new(CONFIG_TEMPLATE, File.join(sandbox_root, 'nginx.conf'), default_attrs)
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
        ssl_cert_path =  File.join(CERTS_DIR, 'serverWithWrongCA.crt')
        ssl_cert_key_path =  File.join(CERTS_DIR, 'serverWithWrongCA.key')
      else
        ssl_cert_path =  File.join(CERTS_DIR, 'server.crt')
        ssl_cert_key_path =  File.join(CERTS_DIR, 'server.key')
      end

      @config.write(ssl_cert_path: ssl_cert_path, ssl_cert_key_path: ssl_cert_key_path)
    end
  end

  class NginxInstaller
    WORKING_DIR = File.join(Bosh::Dev::RELEASE_SRC_DIR, 'tmp', 'integration-nginx-work')
    INSTALL_DIR = File.join(Bosh::Dev::RELEASE_SRC_DIR, 'tmp', 'integration-nginx')
    EXECUTABLE_PATH = File.join(INSTALL_DIR, 'sbin', 'nginx')

    def initialize(runner:)
      @runner = runner
    end

    def prepare
      sync_release_blobs
      retrieve_nginx_package
    end

    def should_compile?
      !File.file?(EXECUTABLE_PATH) || blob_has_changed? || platform_has_changed?
    end

    def compile
      # Clean up old compiled nginx bits to stay up-to-date
      FileUtils.rm_rf(WORKING_DIR)
      FileUtils.rm_rf(INSTALL_DIR)

      FileUtils.mkdir_p(WORKING_DIR)
      FileUtils.mkdir_p(INSTALL_DIR)

      if /darwin/ =~ RUBY_PLATFORM
        # search homebrew paths for openssl on osx (fixes nginx compilation issues)
        ENV['LDFLAGS'] = '-L/usr/local/opt/openssl/lib'
        ENV['CPPFLAGS'] = '-I/usr/local/opt/openssl/include'
      end
      @runner.run("echo '#{RUBY_PLATFORM}' > #{INSTALL_DIR}/platform")

      # Make sure packaging script has its own blob copies so that blobs/ directory is not affected
      nginx_blobs_path = File.join(Bosh::Dev::RELEASE_ROOT, 'packages', 'nginx')
      @runner.run("cp -R #{nginx_blobs_path}/. #{File.join(WORKING_DIR)}")

      Dir.chdir(WORKING_DIR) do
        packaging_script_path = File.join(Bosh::Dev::RELEASE_ROOT, 'packages', 'nginx', 'packaging')
        @runner.run("bash #{packaging_script_path}", env: {
          'BOSH_INSTALL_TARGET' => INSTALL_DIR,
        })
      end
    end

    private

    def blob_has_changed?
      release_nginx_path = File.join(Bosh::Dev::RELEASE_ROOT, 'blobs', 'nginx')
      blobs_shasum = shasum(release_nginx_path)
      working_dir_nginx_path = "#{WORKING_DIR}/nginx"
      sandbox_copy_shasum = shasum(working_dir_nginx_path)

      blobs_shasum.sort != sandbox_copy_shasum.sort
    end

    def platform_has_changed?
      output = @runner.run("cat #{INSTALL_DIR}/platform || true")
      output != RUBY_PLATFORM
    end

    def shasum(directory)
      output = @runner.run("find #{directory} \\! -type d -print0 | xargs -0 shasum -a 256")
      output.split("\n").map do |line|
        line.split(' ').first
      end
    end

    def sync_release_blobs
      Dir.chdir(Bosh::Dev::RELEASE_ROOT) { @runner.run('bosh sync-blobs') }
    end

    def retrieve_nginx_package
      Dir.chdir(Bosh::Dev::RELEASE_ROOT) do
        @runner.run('bosh create-release --force --tarball /tmp/release.tgz')
        @runner.run('tar -zxvf /tmp/release.tgz -C /tmp packages/nginx.tgz')
        @runner.run('tar -zxvf /tmp/packages/nginx.tgz  -C packages/nginx')
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
