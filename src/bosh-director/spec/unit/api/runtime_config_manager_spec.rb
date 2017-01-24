require 'spec_helper'

describe Bosh::Director::Api::RuntimeConfigManager do
  subject(:manager) { Bosh::Director::Api::RuntimeConfigManager.new }
  let(:valid_runtime_manifest) { YAML.dump(Bosh::Spec::Deployments.simple_runtime_config) }

  describe '#update' do
    it 'saves the runtime config' do
      expect {
        manager.update(valid_runtime_manifest)
      }.to change(Bosh::Director::Models::RuntimeConfig, :count).from(0).to(1)

      runtime_config = Bosh::Director::Models::RuntimeConfig.first
      expect(runtime_config.created_at).to_not be_nil
      expect(runtime_config.properties).to eq(valid_runtime_manifest)
    end

    it 'throws an error if runtime config is not valid YAML' do
      invalid_manifest = ":"
      expect{
        manager.update(invalid_manifest)
      }.to raise_error Bosh::Director::InvalidYamlError
    end
  end

  describe '#list' do
    it 'returns the specified number of runtime configs (most recent first)' do
      days = 24*60*60

      Bosh::Director::Models::RuntimeConfig.new(
        properties: 'config_from_time_immortal',
        created_at: Time.now - 3*days,
      ).save
      older_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
        properties: 'config_from_yesteryear',
        created_at: Time.now - 2*days,
      ).save
      newer_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      runtime_configs = manager.list(2)

      expect(runtime_configs.count).to eq(2)
      expect(runtime_configs[0]).to eq(newer_runtime_config)
      expect(runtime_configs[1]).to eq(older_runtime_config)
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      Bosh::Director::Models::RuntimeConfig.new(
        properties: 'config_from_last_year',
        created_at: Time.now - 2*days,
      ).save
      newer_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      runtime_config = manager.latest

      expect(runtime_config).to eq(newer_runtime_config)
    end

    it 'returns nil if there are no cloud configs' do
      runtime_config = manager.latest

      expect(runtime_config).to be_nil
    end
  end
end
