require 'integration_support/constants'

module IntegrationSupport
  module BoshAgent
    SOURCE_DIR = File.join(IntegrationSupport::Constants::BOSH_REPO_PARENT_DIR, 'bosh-agent')
    COMPILED_BOSH_AGENT = File.join(SOURCE_DIR, 'out', 'bosh-agent')

    def self.install
      return if File.exist?(executable_path)

      raise "The bosh-agent source must be a sibling to the BOSH Director repo" unless File.exist?(SOURCE_DIR)

      Dir.chdir(SOURCE_DIR) do
        system('bin/build') || raise('Unable to build bosh-agent')
      end
      raise 'Expected bosh-agent binary to exist, but it does not' unless File.exist?(COMPILED_BOSH_AGENT)

      FileUtils.cp(COMPILED_BOSH_AGENT, executable_path)
    end

    def self.executable_path
      File.join(IntegrationSupport::Constants::INTEGRATION_BIN_DIR, 'bosh-agent')
    end
  end
end

