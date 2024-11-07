module IntegrationSupport
  class VerifyMultidigestManager
    def self.install
      installer.install
    end

    def self.executable_path
      installer.executable_path
    end

    def self.installer
      @installer ||= VerifyMultidigestBlobInstaller.new
    end

    private_class_method :installer
  end

  class VerifyMultidigestBlobInstaller
    INSTALL_DIR = File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'tmp', 'integration-verify-multidigest')

    def install
      Dir.chdir(IntegrationSupport::Constants::BOSH_REPO_ROOT) do
        run_command("mkdir -p #{INSTALL_DIR}")
        run_command('bosh sync-blobs')
        run_command("cp blobs/verify-multidigest/verify-multidigest-*-linux-amd64 #{executable_path}")
        run_command("chmod +x #{executable_path}")
      end
    end

    def executable_path
      File.join(INSTALL_DIR, 'verify-multidigest')
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
