require 'spec_helper'

describe Bosh::Director::Api::CpiConfigManager do
  subject(:manager) { Bosh::Director::Api::CpiConfigManager.new }
  let(:valid_cpi_manifest) { YAML.dump(Bosh::Spec::Deployments.simple_cpi_config) }
  let(:user) {'username-1'}
  let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}

  describe '#update' do
    it 'saves the cpi config' do
      expect {
        manager.update(valid_cpi_manifest)
      }.to change(Bosh::Director::Models::CpiConfig, :count).from(0).to(1)

      cpi_config = Bosh::Director::Models::CpiConfig.first
      expect(cpi_config.created_at).to_not be_nil
      expect(cpi_config.properties).to eq(valid_cpi_manifest)
    end

    context 'when cpi config is failing to parse' do
      it 'returns an error' do
        cpi_config_yaml = 'invalid cpi config'
        expect {
          manager.update(cpi_config_yaml)
        }.to raise_error Bosh::Director::ValidationInvalidType
        expect(Bosh::Director::Models::CpiConfig.count).to eq(0)
      end
    end
  end

  describe '#list' do
    it 'returns the specified number of cpi configs (most recent first)' do
      days = 24*60*60

      oldest_cpi_config = Bosh::Director::Models::CpiConfig.new(
          properties: 'config_from_time_immortal',
          created_at: Time.now - 3*days,
      ).save
      older_cpi_config = Bosh::Director::Models::CpiConfig.new(
          properties: 'config_from_last_year',
          created_at: Time.now - 2*days,
      ).save
      newer_cpi_config = Bosh::Director::Models::CpiConfig.new(
          properties: "---\nsuper_shiny: new_config",
          created_at: Time.now - 1*days,
      ).save

      cpi_configs = manager.list(2)

      expect(cpi_configs.count).to eq(2)
      expect(cpi_configs[0]).to eq(newer_cpi_config)
      expect(cpi_configs[1]).to eq(older_cpi_config)
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      older_cpi_config = Bosh::Director::Models::CpiConfig.new(
          properties: 'config_from_last_year',
          created_at: Time.now - 2*days,
      ).save
      newer_cpi_config = Bosh::Director::Models::CpiConfig.new(
          properties: "---\nsuper_shiny: new_config",
          created_at: Time.now - 1*days,
      ).save

      cpi_config = manager.latest

      expect(cpi_config).to eq(newer_cpi_config)
    end

    it 'returns nil if there are no cpi configs' do
      cpi_config = manager.latest

      expect(cpi_config).to be_nil
    end
  end
end
