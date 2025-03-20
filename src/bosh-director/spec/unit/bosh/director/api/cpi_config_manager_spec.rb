require 'spec_helper'

describe Bosh::Director::Api::CpiConfigManager do
  subject(:manager) { Bosh::Director::Api::CpiConfigManager.new }
  let(:valid_cpi_manifest) { SharedSupport::DeploymentManifestHelper.multi_cpi_config }
  let(:dumped_valid_cpi_manifest)  { YAML.dump(valid_cpi_manifest) }
  let(:user) {'username-1'}

  describe '#update' do
    it 'saves the cpi config' do
      expect {
        manager.update(dumped_valid_cpi_manifest)
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      cpi_config = Bosh::Director::Models::Config.first
      expect(cpi_config.created_at).to_not be_nil
      expect(cpi_config.type).to eq('cpi')
      expect(cpi_config.name).to eq('default')
      expect(cpi_config.content).to eq(dumped_valid_cpi_manifest)
      expect(cpi_config.raw_manifest).to eq(valid_cpi_manifest)
    end

    context 'when cpi config is failing to parse' do
      it 'returns an error' do
        cpi_config_yaml = 'invalid cpi config'
        expect {
          manager.update(cpi_config_yaml)
        }.to raise_error Bosh::Director::ValidationInvalidType
        expect(Bosh::Director::Models::Config.count).to eq(0)
      end
    end
  end

  describe '#list' do
    before(:each) do
      days = 24*60*60

      @oldest_cpi_config = FactoryBot.create(:models_config_cpi,
                                          content: 'config_from_time_immortal',
                                          created_at: Time.now - 3*days,
                                          )
      @older_cpi_config = FactoryBot.create(:models_config_cpi,
                                                             content: 'config_from_last_year',
                                                             created_at: Time.now - 2*days,
                                                             )
      @newer_cpi_config = FactoryBot.create(:models_config_cpi,
                                                             content: "---\nsuper_shiny: new_config",
                                                             created_at: Time.now - 1*days,
                                                             )
    end

    it 'returns the specified number of cpi configs (most recent first)' do
      cpi_configs = manager.list(2)

      expect(cpi_configs.count).to eq(2)
      expect(cpi_configs[0]).to eq(@newer_cpi_config)
      expect(cpi_configs[1]).to eq(@older_cpi_config)
    end

    it 'returns only configs of type `cpi` and name `default`' do
      FactoryBot.create(:models_config_cpi, name: 'non-default')
      FactoryBot.create(:models_config_cloud)

      cpi_configs = manager.list(4)

      expect(cpi_configs.count).to eq(3)
      expect(cpi_configs[0]).to eq(@newer_cpi_config)
      expect(cpi_configs[1]).to eq(@older_cpi_config)
      expect(cpi_configs[2]).to eq(@oldest_cpi_config)
    end

    context 'when there are deleted cpi configs' do
      before(:each) do
        @older_cpi_config.update(deleted: true)
      end

      it 'ignores the deleted configs from the result' do
        runtime_configs = manager.list(2)

        expect(runtime_configs).to eq([@newer_cpi_config, @oldest_cpi_config])
      end
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      FactoryBot.create(:models_config_cpi,
          content: 'config_from_last_year',
          created_at: Time.now - 2*days,
      ).save
      newer_cpi_config = FactoryBot.create(:models_config_cpi,
          content: "---\nsuper_shiny: new_config",
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
