# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::ResourcePool do
  before do
    @client = double(:client)
    VSphereCloud::Config.client = @client
    VSphereCloud::Config.mem_overcommit = 1.0
  end

  describe "#initialize" do
    it "should create a resource pool" do
      cluster = double(:cluster)
      cluster_config = VSphereCloud::Config::ClusterConfig.new("foo")
      cluster.stub(:config).and_return(cluster_config)
      root_resource_pool_mob = double(:root_resource_pool)

      resource_pool = VSphereCloud::Resources::ResourcePool.new(
          cluster, root_resource_pool_mob)
      resource_pool.mob.should == root_resource_pool_mob
    end

    it "should create a resource pool with the specified name" do
      cluster = double(:cluster)
      cluster_config = VSphereCloud::Config::ClusterConfig.new(
          {"foo" => {"resource_pool" => "bar"}})
      cluster.stub(:config).and_return(cluster_config)
      root_resource_pool_mob = double(:root_resource_pool)

      child_resource_pool_mob = double(:child_resource_pool_mob)
      @client.should_receive(:get_managed_object).
          with(VimSdk::Vim::ResourcePool,
               {:root=> root_resource_pool_mob, :name=>"bar"}).
          and_return(child_resource_pool_mob)

      resource_pool = VSphereCloud::Resources::ResourcePool.new(
          cluster, root_resource_pool_mob)
      resource_pool.mob.should == child_resource_pool_mob
    end
  end
end
