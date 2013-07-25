require "spec_helper"

describe Bosh::Agent::Settings do
  describe "load" do
    let(:settings) {Bosh::Agent::Settings.new(asset("settings.yml"))}

    it "should load settings from infrastructure" do
      settings.should_receive(:load_from_infrastructure)
      settings.should_receive(:cache)

      settings.load
    end

    it "should fallback to cached settings" do
      settings.should_receive(:load_from_infrastructure).and_raise(Bosh::Agent::LoadSettingsError)
      settings.should_not_receive(:cache)

      settings.load
      settings["foo"].should == "bar"
    end

    it "should raise error when it can't fallback to cache" do
      settings.should_receive(:load_from_infrastructure).and_raise(Bosh::Agent::LoadSettingsError)
      settings.should_receive(:load_from_cache).and_raise(Bosh::Agent::LoadSettingsError)
      settings.should_not_receive(:cache)

      expect {
        settings.load
      }.to raise_error Bosh::Agent::LoadSettingsError
    end
  end

  describe "store" do
    it "should store settings" do
      Dir.mktmpdir do |dir|
        file = File.join(dir, "settings.yml")
        settings = Bosh::Agent::Settings.new(file)

        i = double("infrastructure", :load_settings => {"foo" => "bar"})
        Bosh::Agent::Config.should_receive(:infrastructure).and_return(i)

        settings.load
        File.open(file).read.should == '{"foo":"bar"}'
      end
    end
  end
end
