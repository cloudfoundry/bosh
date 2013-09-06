require 'bosh_agent/config'

describe Bosh::Agent::Config do
  describe '.platform' do
    subject(:config_class) do
      # do not mutate state of the described class with class methods
      config_klass = Class.new(described_class)
      config_klass.setup('platform_name' => 'ubuntu', 'infrastructure_name' => 'dummy')
      stub_const('Bosh::Agent::Config', config_klass)
    end

    it "returns an Ubuntu if platform_name is configured to be 'ubuntu'" do
      expect(config_class.platform).to be_a(Bosh::Agent::Platform::Ubuntu)
    end
  end
end
