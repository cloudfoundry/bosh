module IntegrationSupport
  class GnatsdManager
    def self.install
      installer.install
    end

    def self.executable_path
      installer.executable_path
    end

    def self.installer
      @installer ||= NatsServerBlobInstaller.new
    end

    private_class_method :installer
  end

  class NatsServerBlobInstaller
    INSTALL_DIR = File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'tmp', 'integration-nats')

    def install
      Dir.chdir(IntegrationSupport::Constants::BOSH_REPO_ROOT) do
        run_command("mkdir -p #{INSTALL_DIR}")
        run_command('bosh sync-blobs')
        run_command('tar -zxvf blobs/nats/nats-server-*.tar.gz -C /tmp')
        run_command("cp /tmp/nats-server-*/nats-server #{executable_path}")
        run_command("chmod +x #{executable_path}")
      end
    end

    def executable_path
      File.join(INSTALL_DIR, 'nats-server')
    end

    private

    def run_command(command, environment = {})
      io = IO.popen([environment, 'bash', '-c', command])

      lines =
        io.each_with_object("") do |line, collect|
          collect << line
          puts line.chomp
        end

      io.close

      lines
    end
  end
end
