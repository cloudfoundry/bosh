require 'spec_helper'

describe Bosh::Director::Api::CloudConfigManager do
  subject(:manager) { Bosh::Director::Api::CloudConfigManager.new }
  let(:valid_cloud_manifest) { YAML.dump(Bosh::Spec::Deployments.simple_cloud_config) }
  let(:user) {'username-1'}
  let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}

  describe '#update' do
    it 'saves the cloud config' do
      expect {
        manager.update(valid_cloud_manifest)
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      cloud_config = Bosh::Director::Models::Config.first
      expect(cloud_config.created_at).to_not be_nil
      expect(cloud_config.content).to eq(valid_cloud_manifest)
    end

    context 'when cloud config uses placeholders' do
      let(:cloud_config_with_placeholders) { YAML.dump(Bosh::Spec::Deployments.cloud_config_with_placeholders) }

      it 'does not error on update' do
        expect {
          manager.update(cloud_config_with_placeholders)
        }.to_not raise_error
      end
    end
  end

  describe '#list' do
    it 'returns the specified number of cloud configs (most recent first)' do
      days = 24*60*60

      oldest_cloud_config = Bosh::Director::Models::Config.make(
        :cloud,
        content: 'config_from_time_immortal',
        created_at: Time.now - 3*days,
      ).save
      older_cloud_config = Bosh::Director::Models::Config.make(
        :cloud,
        content: 'config_from_last_year',
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::Config.make(
        :cloud,
        content: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      cloud_configs = manager.list(2)

      expect(cloud_configs.count).to eq(2)
      expect(cloud_configs[0]).to eq(newer_cloud_config)
      expect(cloud_configs[0].content).to eq( "---\nsuper_shiny: new_config")
      expect(cloud_configs[1]).to eq(older_cloud_config)
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      older_cloud_config = Bosh::Director::Models::Config.make(
        :cloud,
        content: 'config_from_last_year',
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::Config.make(
        :cloud,
        content: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      cloud_config = manager.latest

      expect(cloud_config).to eq(newer_cloud_config)
    end

    it 'returns nil if there are no cloud configs' do
      cloud_config = manager.latest

      expect(cloud_config).to be_nil
    end
  end

  describe '.interpolated_manifest' do
    let(:cloud_config_model) { Bosh::Director::Models::Config.make(raw_manifest: raw_manifest) }
    let(:raw_manifest) { {name: '((manifest_name))'} }
    let(:interpolated_manifest) { {name: 'cloud config manifest'} }
    let(:deployment_name) { 'some_deployment_name' }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    before do
      allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
      allow(variables_interpolator).to receive(:interpolate_cloud_manifest).with(raw_manifest, deployment_name).and_return(interpolated_manifest)
    end

    it 'returns interpolated manifest' do
      result = Bosh::Director::Api::CloudConfigManager.interpolated_manifest(cloud_config_model, deployment_name)
      expect(result).to eq(interpolated_manifest)
    end
  end
end
