require 'fileutils'
require 'open3'
require 'shellwords'
require 'integration_support/constants'

module IntegrationSupport
  class BoshMonitorManager
    def self.build
      manager.build
    end

    def self.executable_path
      manager.executable_path
    end

    def self.manager
      @manager ||= BoshMonitorBuilder.new
    end

    private_class_method :manager
  end

  class BoshMonitorBuilder
    PLUGIN_NAMES = %w[
      hm-consul
      hm-datadog
      hm-dummy
      hm-email
      hm-event-logger
      hm-graphite
      hm-json
      hm-logger
      hm-pagerduty
      hm-resurrector
      hm-riemann
      hm-tsdb
    ].freeze

    def build
      source_dir = File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'bosh-monitor')
      FileUtils.mkdir_p(File.dirname(executable_path))

      go_version, = Open3.capture2('go', 'version')
      puts "Building with #{go_version.chomp}..."

      unless File.exist?(executable_path)
        run_command("go build -o #{Shellwords.escape(executable_path)} .", source_dir)
      end

      PLUGIN_NAMES.each do |plugin|
        plugin_bin = File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, plugin)
        next if File.exist?(plugin_bin)

        run_command("go build -o #{Shellwords.escape(plugin_bin)} ./cmd/plugins/#{plugin}", source_dir)
      end
    end

    def executable_path
      File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'bosh-monitor')
    end

    private

    def run_command(command, dir = nil)
      cmd = dir ? "cd #{Shellwords.escape(dir)} && #{command}" : command
      output = String.new
      status = nil

      Open3.popen2e('bash', '-c', cmd) do |_stdin, stdout_err, thread|
        stdout_err.each_line do |line|
          output << line
          puts line.chomp
        end
        status = thread.value
      end

      raise "Command failed (exit #{status.exitstatus}): #{command}" unless status.success?

      output
    end
  end
end
