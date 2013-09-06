require 'bosh_agent/config'

describe Bosh::Agent::Config do
  describe '.platform' do
    it "returns an Ubuntu if platform_name is configured to be 'ubuntu'" do
      # do not mutate state of the described class with class methods
      klass = Class.new(described_class)
      klass.setup('platform_name' => 'ubuntu', 'infrastructure_name' => 'dummy')

      stub_const('Bosh::Agent::Config', klass)
      klass.platform.should be_a(Bosh::Agent::Platform::Ubuntu)
    end
  end
end
