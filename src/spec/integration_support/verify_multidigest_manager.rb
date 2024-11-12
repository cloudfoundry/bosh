require 'integration_support/constants'

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
    def install
      return if File.exist?(executable_path)

      Dir.chdir(IntegrationSupport::Constants::BOSH_REPO_ROOT) do
        run_command('bosh sync-blobs')
        run_command("cp blobs/verify-multidigest/verify-multidigest-*-linux-amd64 #{executable_path}")
        run_command("chmod +x #{executable_path}")
      end
    end

    def executable_path
      File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'verify-multidigest')
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
