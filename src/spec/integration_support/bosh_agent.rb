module IntegrationSupport
  module BoshAgent
    BOSH_REPO_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..')).freeze
    BOSH_AGENT_SRC = File.join(BOSH_REPO_ROOT, 'src/bosh-agent')
    COMPILED_BOSH_AGENT = File.join(BOSH_AGENT_SRC, 'out', 'bosh-agent')

    def self.ensure_agent_exists!
      unless File.exist?(COMPILED_BOSH_AGENT) || ENV['TEST_ENV_NUMBER']
        puts "Building agent in #{COMPILED_BOSH_AGENT}..."

        raise 'Bosh agent build failed' unless system(File.join(BOSH_AGENT_SRC, 'bin', 'build'))
      end
    end
  end
end

RSpec.configure do |c|
  c.before(:suite) do
    IntegrationSupport::BoshAgent.ensure_agent_exists!
  end
end
