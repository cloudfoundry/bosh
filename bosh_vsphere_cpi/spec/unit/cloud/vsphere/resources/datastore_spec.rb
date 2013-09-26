# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::Datastore do
  before do
    @client = double(:client)
    VSphereCloud::Config.client = @client
    VSphereCloud::Config.mem_overcommit = 1.0
  end

  describe "#initialize" do
    it "should create a datastore" do
      ds_mob = double(:ds_mob)
      datastore = VSphereCloud::Resources::Datastore.new({
          :obj => ds_mob,
          "name" => "foo_lun",
          "summary.capacity" => 16 * 1024 * 1024 * 1024,
          "summary.freeSpace" => 8 * 1024 * 1024 * 1024
      })

      datastore.mob.should == ds_mob
      datastore.total_space.should == 16384
      datastore.free_space.should == 8192
      datastore.synced_free_space.should == 8192
      datastore.allocated_after_sync.should == 0
    end
  end

  describe :allocate do
    it "should allocate space" do
      ds_mob = double(:ds_mob)
      datastore = VSphereCloud::Resources::Datastore.new({
         :obj => ds_mob,
         "name" => "foo_lun",
         "summary.capacity" => 16 * 1024 * 1024 * 1024,
         "summary.freeSpace" => 8 * 1024 * 1024 * 1024
      })
      datastore.allocate(1024)
      datastore.free_space.should == 7168
    end
  end
end
