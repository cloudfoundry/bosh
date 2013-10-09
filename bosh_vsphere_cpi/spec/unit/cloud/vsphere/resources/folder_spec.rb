# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::Folder do
  before do
    @client = double(:client)
    VSphereCloud::Config.client = @client
    VSphereCloud::Config.mem_overcommit = 1.0
  end

  describe "#initialize" do
    it "should create a folder" do
      datacenter = double(:datacenter)
      datacenter.stub(:name).and_return("TEST_DC")

      folder_mob = double(:folder_mob)

      @client.should_receive(:find_by_inventory_path).with(%w(TEST_DC vm foo)).
          and_return(folder_mob)

      folder = VSphereCloud::Resources::Folder.new(datacenter, "foo", false)
      folder.mob.should == folder_mob
      folder.name.should == "foo"
    end

    it "should create a namespaced folder" do
      datacenter = double(:datacenter)
      datacenter.stub(:name).and_return("TEST_DC")

      folder_mob = double(:folder_mob)
      @client.should_receive(:find_by_inventory_path).with(%w(TEST_DC vm foo)).
          and_return(folder_mob)

      ns_folder_mob = double(:ns_folder_mob)
      @client.should_receive(:find_by_inventory_path).
          with(["TEST_DC", "vm", %w(foo 123)]).and_return(ns_folder_mob)

      folder = VSphereCloud::Resources::Folder.new(datacenter, "foo", true)
      folder.mob.should == ns_folder_mob
      folder.name.should == %w(foo 123)
    end

    it "should create a namespaced folder and create it in vSphere" do
      datacenter = double(:datacenter)
      datacenter.stub(:name).and_return("TEST_DC")

      folder_mob = double(:folder_mob)
      @client.should_receive(:find_by_inventory_path).with(%w(TEST_DC vm foo)).
          and_return(folder_mob)
      @client.should_receive(:find_by_inventory_path).
          with(["TEST_DC", "vm", %w(foo 123)]).and_return(nil)

      ns_folder_mob = double(:ns_folder_mob)
      folder_mob.should_receive(:create_folder).with("123").
          and_return(ns_folder_mob)

      folder = VSphereCloud::Resources::Folder.new(datacenter, "foo", true)
      folder.mob.should == ns_folder_mob
      folder.name.should == %w(foo 123)
    end
  end
end
