# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::Datacenter do
  before do
    @client = double(:client)
    VSphereCloud::Config.client = @client
    VSphereCloud::Config.mem_overcommit = 1.0
  end

  describe "#initialize" do
    it "should create a datacenter" do
      dc_mob = double(:dc_mob)
      cluster_mob = double(:cluster_mob)

      @client.should_receive(:find_by_inventory_path).with("TEST_DC").
          and_return(dc_mob)
      @client.should_receive(:get_managed_objects).
          with(VimSdk::Vim::ClusterComputeResource,
               {:root=>dc_mob, :include_name=>true}).
          and_return({"foo" => cluster_mob})
      @client.should_receive(:get_properties).
          with([cluster_mob], VimSdk::Vim::ClusterComputeResource,
               %w(name datastore resourcePool host), {:ensure_all => true}).
          and_return({cluster_mob => {:foo => :bar}})

      folder_config = VSphereCloud::Config::FolderConfig.new
      folder_config.vm = "vms"
      folder_config.template = "templates"
      folder_config.shared = false
      cluster_config = VSphereCloud::Config::ClusterConfig.new("foo")
      datastore_config = VSphereCloud::Config::DatastoreConfig.new
      datastore_config.disk_path = "bosh_disks"

      dc_config = double(:dc_config)
      dc_config.stub(:name).and_return("TEST_DC")
      dc_config.stub(:folders).and_return(folder_config)
      dc_config.stub(:clusters).and_return({"foo" => cluster_config})
      dc_config.stub(:datastores).and_return(datastore_config)

      vm_folder = double(:vm_folder)
      VSphereCloud::Resources::Folder.stub(:new).
          with(an_instance_of(VSphereCloud::Resources::Datacenter),
               "vms", false).
          and_return(vm_folder)

      template_folder = double(:template_folder)
      VSphereCloud::Resources::Folder.stub(:new).
          with(an_instance_of(VSphereCloud::Resources::Datacenter),
               "templates", false).
          and_return(template_folder)

      cluster = double(:cluster)
      cluster.stub(:name).and_return("foo")
      VSphereCloud::Resources::Cluster.stub(:new).
          with(an_instance_of(VSphereCloud::Resources::Datacenter),
               cluster_config, {:foo => :bar}).
          and_return(cluster)

      datacenter = VSphereCloud::Resources::Datacenter.new(dc_config)
      datacenter.mob.should == dc_mob
      datacenter.clusters.should == {"foo" => cluster}
      datacenter.vm_folder.should == vm_folder
      datacenter.template_folder.should == template_folder
      datacenter.config.should == dc_config
      datacenter.name.should == "TEST_DC"
      datacenter.disk_path.should == "bosh_disks"
    end

  end
end
