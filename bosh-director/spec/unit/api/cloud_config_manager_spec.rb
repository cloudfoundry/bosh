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
end
