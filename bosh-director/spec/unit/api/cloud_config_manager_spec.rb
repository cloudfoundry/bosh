require 'spec_helper'

describe Bosh::Director::Api::CloudConfigManager do
  describe "#update" do
    it "saves the cloud config" do
      manager = Bosh::Director::Api::CloudConfigManager.new
      cloud_config_yaml = "here's my cloud config"
      expect {
        manager.update(cloud_config_yaml)
      }.to change(Bosh::Director::Models::CloudConfig, :count).from(0).to(1)

      cloud_config = Bosh::Director::Models::CloudConfig.first
      expect(cloud_config.created_at).to_not be_nil
      expect(cloud_config.properties).to eq(cloud_config_yaml)
    end
  end

  describe "#list" do
    it "returns the specified number of cloud configs (most recent first)" do
      days = 24*60*60

      oldest_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "config_from_time_immortal",
        created_at: Time.now - 3*days,
      ).save
      older_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "config_from_last_year",
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      manager = Bosh::Director::Api::CloudConfigManager.new

      cloud_configs = manager.list(2)

      expect(cloud_configs.count).to eq(2)
      expect(cloud_configs[0]).to eq(newer_cloud_config)
      expect(cloud_configs[1]).to eq(older_cloud_config)
    end
  end

  describe "#latest" do
    it "returns the latest" do
      days = 24*60*60

      older_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "config_from_last_year",
        created_at: Time.now - 2*days,
      ).save
      newer_cloud_config = Bosh::Director::Models::CloudConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      manager = Bosh::Director::Api::CloudConfigManager.new

      cloud_config = manager.latest

      expect(cloud_config).to eq(newer_cloud_config)
    end

    it "returns nil if there are no cloud configs" do
      manager = Bosh::Director::Api::CloudConfigManager.new

      cloud_config = manager.latest

      expect(cloud_config).to be_nil
    end
  end
end
