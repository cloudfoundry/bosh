require 'spec_helper'

describe Bosh::Director::Api::CloudConfigManager do
  subject(:manager) { Bosh::Director::Api::CloudConfigManager.new }
  let(:valid_cloud_manifest) { Psych.dump(Bosh::Spec::Deployments.simple_cloud_config) }
  let(:user) {'username-1'}
  let(:event_manager) {Bosh::Director::Api::EventManager.new}

  describe '#update' do
    it 'saves the cloud config' do
      expect {
        manager.update(valid_cloud_manifest, event_manager, user)
      }.to change(Bosh::Director::Models::CloudConfig, :count).from(0).to(1)

      cloud_config = Bosh::Director::Models::CloudConfig.first
      expect(cloud_config.created_at).to_not be_nil
      expect(cloud_config.properties).to eq(valid_cloud_manifest)
    end

    it 'saves the event' do
      expect {
        manager.update(valid_cloud_manifest, event_manager, user)
      }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)

      event = Bosh::Director::Models::Event.first
      expect(event.object_type).to eq("cloud-config")
      expect(event.action).to eq("update")
      expect(event.user).to eq(user)
    end

    context 'when cloud config is failing to parse' do
      it 'returns an error' do
        cloud_config_yaml = 'invalid cloud config'
        expect {
          manager.update(cloud_config_yaml, event_manager, user)
        }.to raise_error Bosh::Director::ValidationInvalidType
        expect(Bosh::Director::Models::CloudConfig.count).to eq(0)
      end

      it 'saves the event with error information' do
        cloud_config_yaml = 'invalid cloud config'
        expect(manager).to receive(:validate_manifest!).and_raise Bosh::Director::DeploymentNoResourcePools, 'No resource_pools specified'
        expect {
          manager.update(cloud_config_yaml, event_manager, user)
        }.to raise_error Bosh::Director::DeploymentNoResourcePools
        expect(Bosh::Director::Models::Event.count).to eq(1)

        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq("cloud-config")
        expect(event.action).to eq("update")
        expect(event.user).to eq(user)
        expect(event.error).to eq('No resource_pools specified')
      end
    end
  end

  describe '#list' do
    it 'returns the specified number of cloud configs (most recent first)' do
      days = 24*60*60

      oldest_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: 'config_from_time_immortal',
        created_at: Time.now - 3*days,
      ).save
      older_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: 'config_from_last_year',
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      cloud_configs = manager.list(2)

      expect(cloud_configs.count).to eq(2)
      expect(cloud_configs[0]).to eq(newer_cloud_config)
      expect(cloud_configs[1]).to eq(older_cloud_config)
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      older_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: 'config_from_last_year',
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "---\nsuper_shiny: new_config",
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
end
