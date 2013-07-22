# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::Cluster do
  before(:each) do
    @client = double(:client)
    VSphereCloud::Config.client = @client
    VSphereCloud::Config.mem_overcommit = 1.0
    @dc = double(:datacenter)
    @dc_config = double(:datacenter_config)
    @dc.stub(:config).and_return(@dc_config)
  end

  describe :initialize do
    it "should create a cluster" do
      cluster_mob = double(:cluster_mob)

      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          :obj => cluster_mob,
          "datastore" => []
      })

      cluster.name.should == "foo"
      cluster.mob.should == cluster_mob
      cluster.ephemeral_datastores.should be_empty
      cluster.persistent_datastores.should be_empty
      cluster.shared_datastores.should be_empty
    end

    it "should create a cluster with dedicated datastores" do
      datastore_config = double(:datastore_config)
      datastore_config.stub(:ephemeral_pattern).and_return(/a/)
      datastore_config.stub(:persistent_pattern).and_return(/b/)
      datastore_config.stub(:allow_mixed).and_return(false)
      @dc_config.stub(:datastores).and_return(datastore_config)

      datastore_a = double(:datastore_a)
      datastore_a.stub(:name).and_return("a")
      datastore_a_mob = double(:datastore_a_mob)
      datastore_a_properties = {
          "name" => "a",
          "summary.capacity" => 128 * 1024 * 1024 * 1024,
          "summary.freeSpace" => 32 * 1024 * 1024 * 1024
      }
      VSphereCloud::Resources::Datastore.stub(:new).
          with(datastore_a_properties).and_return(datastore_a)

      datastore_b = double(:datastore_b)
      datastore_b.stub(:name).and_return("b")
      datastore_b_mob = double(:datastore_b_mob)
      datastore_b_properties = {
          "name" => "b",
          "summary.capacity" => 64 * 1024 * 1024 * 1024,
          "summary.freeSpace" => 8 * 1024 * 1024 * 1024
      }
      VSphereCloud::Resources::Datastore.stub(:new).
          with(datastore_b_properties).and_return(datastore_b)

      @client.should_receive(:get_properties).with(
          [datastore_a_mob, datastore_b_mob], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {"a" => datastore_a_properties, "b" => datastore_b_properties})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => [datastore_a_mob, datastore_b_mob]
      })

      cluster.ephemeral_datastores.should == {"a" => datastore_a}
      cluster.persistent_datastores.should == {"b" => datastore_b}
      cluster.shared_datastores.should be_empty
    end

    it "should fail to create a cluster with overlapped dedicated datastores" do
      datastore_config = double(:datastore_config)
      datastore_config.stub(:ephemeral_pattern).and_return(/[ab]/)
      datastore_config.stub(:persistent_pattern).and_return(/b/)
      datastore_config.stub(:allow_mixed).and_return(false)
      @dc_config.stub(:datastores).and_return(datastore_config)

      datastore_a = double(:datastore_a)
      datastore_a.stub(:name).and_return("a")
      datastore_a_mob = double(:datastore_a_mob)
      datastore_a_properties = {
          "name" => "a"
      }
      VSphereCloud::Resources::Datastore.stub(:new).
          with(datastore_a_properties).and_return(datastore_a)

      datastore_b = double(:datastore_b)
      datastore_b.stub(:name).and_return("b")
      datastore_b_mob = double(:datastore_b_mob)
      datastore_b_properties = {
          "name" => "b"
      }
      VSphereCloud::Resources::Datastore.stub(:new).
          with(datastore_b_properties).and_return(datastore_b)

      @client.should_receive(:get_properties).with(
          [datastore_a_mob, datastore_b_mob], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {"a" => datastore_a_properties, "b" => datastore_b_properties})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      expect {
        VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
            "datastore" => [datastore_a_mob, datastore_b_mob]
        })
      }.to raise_error /Datastore patterns are not mutually exclusive/
    end

    it "should create a cluster with shared datastores" do
      datastore_config = double(:datastore_config)
      datastore_config.stub(:ephemeral_pattern).and_return(/a/)
      datastore_config.stub(:persistent_pattern).and_return(/a/)
      datastore_config.stub(:allow_mixed).and_return(true)
      @dc_config.stub(:datastores).and_return(datastore_config)

      datastore_a = double(:datastore_a)
      datastore_a.stub(:name).and_return("a")
      datastore_a_mob = double(:datastore_a_mob)
      datastore_a_properties = {
          "name" => "a",
          "summary.capacity" => 128 * 1024 * 1024 * 1024,
          "summary.freeSpace" => 32 * 1024 * 1024 * 1024
      }
      VSphereCloud::Resources::Datastore.stub(:new).
          with(datastore_a_properties).and_return(datastore_a)

      @client.should_receive(:get_properties).with(
          [datastore_a_mob], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {"a" => datastore_a_properties})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => [datastore_a_mob]
      })

      cluster.ephemeral_datastores.should be_empty
      cluster.persistent_datastores.should be_empty
      cluster.shared_datastores.should == {"a" => datastore_a}
    end

    it "should create a cluster without a resource pool" do
      host = double(:host)
      host_properties = {
          :obj => host,
          "runtime.inMaintenanceMode" => "false",
          "hardware.memorySize" => 64 * 1024 * 1024 * 1024
      }
      host_counters = {
          "cpu.usage.average" => "1000",
          "mem.usage.average" => "5000"
      }
      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})
      @client.should_receive(:get_properties).with(
          [host], VimSdk::Vim::HostSystem,
          %w(hardware.memorySize runtime.inMaintenanceMode),
          {:ensure_all => true}).and_return(
          {"foo" => host_properties})
      @client.should_receive(:get_perf_counters).with(
          [host], %w(cpu.usage.average mem.usage.average), {:max_sample => 5}).
          and_return({"foo" => host_counters})
      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => [],
          "host" => [host]
      })

      cluster.free_memory.should == 32768
      cluster.total_memory.should == 65536
      cluster.idle_cpu.should == 0.9
    end

    it "should create a cluster with a resource pool" do
      resource_pool = double(:resource_pool)
      resource_pool_mob = double(:resource_pool_mob)
      resource_pool.stub(:mob).and_return(resource_pool_mob)
      VSphereCloud::Resources::ResourcePool.stub(:new).
          with(an_instance_of(VSphereCloud::Resources::Cluster), nil).
          and_return(resource_pool)

      summary = double(:summary)
      runtime = double(:runtime)
      runtime.stub(:overall_status).and_return("green")
      cpu = double(:cpu)
      cpu.stub(:overall_usage).and_return(5)
      cpu.stub(:max_usage).and_return(10)
      runtime.stub(:cpu).and_return(cpu)
      memory = double(:memory)
      memory.stub(:overall_usage).and_return(32 * 1024 * 1024 * 1024)
      memory.stub(:max_usage).and_return(64 * 1024 * 1024 * 1024)
      runtime.stub(:memory).and_return(memory)
      summary.stub(:runtime).and_return(runtime)

      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})
      @client.should_receive(:get_properties).with(
          resource_pool_mob,  VimSdk::Vim::ResourcePool, %w(summary)).
          and_return({"summary" => summary})
      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return("baz")
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => []
      })

      cluster.free_memory.should == 32768
      cluster.total_memory.should == 65536
      cluster.idle_cpu.should == 0.5
    end

    it "should create a cluster with an unhealthy resource pool" do
      resource_pool = double(:resource_pool)
      resource_pool_mob = double(:resource_pool_mob)
      resource_pool.stub(:mob).and_return(resource_pool_mob)
      VSphereCloud::Resources::ResourcePool.stub(:new).
          with(an_instance_of(VSphereCloud::Resources::Cluster), nil).
          and_return(resource_pool)

      summary = double(:summary)
      runtime = double(:runtime)
      runtime.stub(:overall_status).and_return("gray")
      summary.stub(:runtime).and_return(runtime)

      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})
      @client.should_receive(:get_properties).with(
          resource_pool_mob,  VimSdk::Vim::ResourcePool, %w(summary)).
          and_return({"summary" => summary})
      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return("baz")
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => []
      })

      cluster.free_memory.should == 0
      cluster.total_memory.should == 0
      cluster.idle_cpu.should == 0.0
    end
  end

  describe :allocate do
    it "should record the allocation against the cached utilization" do
      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => []
      })
      cluster.instance_eval { @synced_free_memory = 2048 }
      cluster.allocate(1024)
      cluster.free_memory.should == 1024
    end
  end

  describe :pick_persistent do
    before(:each) do
      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      @cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => []
      })
    end

    it "should only use persistent datastores if possible" do
      datastore_a = double(:datastore_a)
      datastore_a.stub(:free_space).and_return(4096)
      datastore_b = double(:datastore_b)

      @cluster.persistent_datastores["foo"] = datastore_a
      @cluster.shared_datastores["bar"] = datastore_b

      VSphereCloud::Resources::Util.should_receive(:weighted_random).
          with([[datastore_a, 4096]]).and_return(datastore_a)

      datastore = @cluster.pick_persistent(1024)
      datastore.should == datastore_a
    end

    it "should filter out datastores that are low on free space" do
      datastore_a = double(:datastore_a)
      datastore_a.stub(:free_space).and_return(2000)
      datastore_b = double(:datastore_b)
      datastore_b.stub(:free_space).and_return(4096)

      @cluster.persistent_datastores["foo"] = datastore_a
      @cluster.shared_datastores["bar"] = datastore_b

      VSphereCloud::Resources::Util.should_receive(:weighted_random).
          with([[datastore_b, 4096]]).and_return(datastore_b)

      datastore = @cluster.pick_persistent(1024)
      datastore.should == datastore_b
    end
  end

  describe :pick_ephemeral do
    it "should only use ephemeral datastores if possible" do
      @client.should_receive(:get_properties).with(
          [], VimSdk::Vim::Datastore,
          %w(summary.freeSpace summary.capacity name)).and_return(
          {})

      VSphereCloud::Resources::Cluster.any_instance.stub(
          :fetch_cluster_utilization)

      cluster_config = double(:cluster_config)
      cluster_config.stub(:name).and_return("foo")
      cluster_config.stub(:resource_pool).and_return(nil)
      @cluster = VSphereCloud::Resources::Cluster.new(@dc, cluster_config, {
          "datastore" => []
      })
      datastore_a = double(:datastore_a)
      datastore_a.stub(:free_space).and_return(4096)
      datastore_b = double(:datastore_b)

      @cluster.ephemeral_datastores["foo"] = datastore_a
      @cluster.shared_datastores["bar"] = datastore_b

      VSphereCloud::Resources::Util.should_receive(:weighted_random).
          with([[datastore_a, 4096]]).and_return(datastore_a)

      datastore = @cluster.pick_ephemeral(1024)
      datastore.should == datastore_a
    end
  end
end