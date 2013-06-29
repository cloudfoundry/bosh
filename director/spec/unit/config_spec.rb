require 'spec_helper'

#
# This supplants the config_old_spec.rb behavior. We are
# moving class behavior to instance behavior.
#

describe Bosh::Director::Config do
  let(:test_config) { Psych.load(spec_asset("test-director-config.yml")) }

  describe 'initialization' do
    it 'loads config from a yaml file' do
      config = described_class.load_file(asset("test-director-config.yml"))
      expect(config.hash).to include('name' => 'Test Director')
    end

    it 'loads config from a hash' do
      config = described_class.load_hash(test_config)
      expect(config.hash).to include('name' => 'Test Director')
    end
  end

end