require "spec_helper"

describe Bosh::Registry::InstanceManager do
  let(:manager) do
    Bosh::Registry::InstanceManager.new()
  end

  def create_instance(params)
    Bosh::Registry::Models::RegistryInstance.create(params)
  end

  describe "reading settings" do
    it "doesn't check remote IP if it's not provided" do
      create_instance(:instance_id => "foo", :settings => "bar")
      expect(manager.read_settings("foo")).to eq("bar")
    end

    it "raises an error if instance not found" do
      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::Registry::InstanceNotFound,
                       "Can't find instance 'foo'")
    end
  end

  describe "updating settings" do
    it "updates settings (new instance)" do
      manager.update_settings("foo", "baz")
      expect(manager.read_settings("foo")).to eq("baz")
    end

    it "updates settings (existing instance)" do
      create_instance(:instance_id => "foo", :settings => "bar")
      expect(manager.read_settings("foo")).to eq("bar")
      manager.update_settings("foo", "baz")
      expect(manager.read_settings("foo")).to eq("baz")
    end
  end

  describe "deleting settings" do
    it "deletes settings" do
      manager.update_settings("foo", "baz")
      manager.delete_settings("foo")

      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::Registry::InstanceNotFound,
                       "Can't find instance 'foo'")
    end

    it "raises an error if instance not found" do
      expect {
        manager.delete_settings("foo")
      }.to raise_error(Bosh::Registry::InstanceNotFound,
                       "Can't find instance 'foo'")
    end
  end
end
