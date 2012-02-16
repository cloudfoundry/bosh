# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe VSphereCloud::Resources do

  def create_datacenter(name)
    datacenter = VSphereCloud::Resources::Datacenter.new
    datacenter.name = name
    datacenter.persistent_datastore_pattern = /.*/
    datacenter.clusters = []
    datacenter
  end

  def create_cluster(name)
    cluster = VSphereCloud::Resources::Cluster.new
    cluster.name = name
    cluster.mob = name
    cluster.total_memory = 2048
    cluster.free_memory = 1024
    cluster.unaccounted_memory = 0
    cluster.mem_over_commit = 1
    cluster.idle_cpu = 0.9
    cluster.datastores = []
    cluster.persistent_datastores = []
    cluster
  end

  def create_datastore(name)
    datastore = VSphereCloud::Resources::Datastore.new
    datastore.name = name
    datastore.total_space = 2048
    datastore.free_space = 1024
    datastore.unaccounted_space = 0
    datastore
  end

  def mark_datastore_full(cluster_index, datastore_index)
    datastore = @datacenters["dc"].clusters[cluster_index].datastores[datastore_index]
    datastore.free_space = 0
  end

  def mark_persistent_datastore_full(cluster_index, datastore_index)
    datastore = @datacenters["dc"].clusters[cluster_index].persistent_datastores[datastore_index]
    datastore.free_space = 0
  end

  before(:each) do
    @resources = VSphereCloud::Resources.new("client", "vcenter")
    datacenter = create_datacenter("dc")
    3.times do |n|
      cluster = create_cluster("cluster#{n}")
      2.times do |x|
        cluster.datastores << create_datastore("#{cluster.name}-#{x}")
      end
      2.times do |x|
        cluster.persistent_datastores << create_datastore("#{cluster.name}-p-#{x}")
      end
      datacenter.clusters << cluster
    end
    @datacenters = {}
    @datacenters[datacenter.name] = datacenter
  end


  it "should raise exception if no resources available" do
    @resources.stub!(:find_resources).and_return([])
    got_exception = false
    begin
      @resources.get_resources
    rescue => e
      if e.message == "No available resources"
        got_exception = true
      end
    end
    got_exception.should be_true
  end

  it "should match given persistent disk affinity" do
    @resources.stub!(:datacenters).and_return(@datacenters)
    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should match(/cluster0*/)
  end

  it "should match expected datastore and cluster" do
    mark_datastore_full(0, 0)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should == "cluster0-1"
  end

  it "should match expected datastore and cluster" do
    mark_datastore_full(0, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should == "cluster0-0"
  end

  it "should match next available datastore and cluster" do
    mark_datastore_full(0, 0)
    mark_datastore_full(0, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should_not match(/cluster0/)
    datastore.name.should_not match(/cluster0/)
  end

  it "should match given persistent datastore affinity" do
    mark_persistent_datastore_full(0, 0)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should match(/cluster0*/)
  end

  it "should match given persistent datastore affinity" do
    mark_persistent_datastore_full(0, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should match(/cluster0*/)
  end

  it "should match next available datastore and cluster" do
    mark_persistent_datastore_full(0, 0)
    mark_persistent_datastore_full(0, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should_not match(/cluster0/)
    datastore.name.should_not match(/cluster0/)
  end

  it "should match the cluster with largest footprint" do
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster2-p-0", "size" => 512}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-1", "size" => 200}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster2"
    datastore.name.should match(/cluster2/)
  end

  it "should match the cluster with largest cummulative footprint" do
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-0", "size" => 200}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster2-p-0", "size" => 256}
    disks << {"persistent" => true, "datacenter" => "dc", "datastore" => "cluster0-p-1", "size" => 200}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should == "cluster0"
    datastore.name.should match(/cluster0/)
  end

  it "should match any available datastore and cluster" do
    @resources.stub!(:datacenters).and_return(@datacenters)

    disks = []
    disks << {"size" => 100}
    cluster, datastore = @resources.get_resources(0, disks)
    cluster.name.should_not be_nil
    datastore.name.should_not be_nil
  end

  it "should match any available datastore and cluster" do
    @resources.stub!(:datacenters).and_return(@datacenters)
    cluster, datastore = @resources.get_resources
    cluster.name.should_not be_nil
    datastore.name.should_not be_nil
  end

  it "should match the exact expected datastore and cluster" do
    mark_persistent_datastore_full(0, 0)
    mark_persistent_datastore_full(0, 1)
    mark_persistent_datastore_full(1, 0)
    mark_persistent_datastore_full(1, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)
    cluster, datastore = @resources.get_resources
    cluster.name.should == "cluster2"
    datastore.name.should match(/cluster2/)
  end

  it "should raise an exception if all persistent datastores are full" do
    mark_persistent_datastore_full(0, 0)
    mark_persistent_datastore_full(0, 1)
    mark_persistent_datastore_full(1, 0)
    mark_persistent_datastore_full(1, 1)
    mark_persistent_datastore_full(2, 0)
    mark_persistent_datastore_full(2, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)
    got_exception = false
    begin
    cluster, datastore = @resources.get_resources
    rescue => e
      if e.message == "No available resources"
        got_exception = true
      end
    end
    got_exception.should be_true
  end

  it "should raise an exception if all nonpersistent datastores are full" do
    mark_datastore_full(0, 0)
    mark_datastore_full(0, 1)
    mark_datastore_full(1, 0)
    mark_datastore_full(1, 1)
    mark_datastore_full(2, 0)
    mark_datastore_full(2, 1)
    @resources.stub!(:datacenters).and_return(@datacenters)
    got_exception = false
    begin
    cluster, datastore = @resources.get_resources
    rescue => e
      if e.message == "No available resources"
        got_exception = true
      end
    end
    got_exception.should be_true
  end
end
