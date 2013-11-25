# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources do

  describe :datacenters do
    it "should fetch the datacenters the first time" do
      vcenter_config = double(:vcenter_config)
      VSphereCloud::Config.vcenter = vcenter_config
      dc_config = double(:dc_config)
      dc_config.stub(:name).and_return("foo")
      vcenter_config.stub(:datacenters).and_return({"foo" => dc_config})
      dc = double(:dc)
      VSphereCloud::Resources::Datacenter.should_receive(:new).with(dc_config).
          once.and_return(dc)

      resources = VSphereCloud::Resources.new
      resources.datacenters.should == {"foo" => dc}
    end

    it "should use cached datacenters" do
      vcenter_config = double(:vcenter_config)
      VSphereCloud::Config.vcenter = vcenter_config
      dc_config = double(:dc_config)
      dc_config.stub(:name).and_return("foo")
      vcenter_config.stub(:datacenters).and_return({"foo" => dc_config})
      dc = double(:dc)
      VSphereCloud::Resources::Datacenter.should_receive(:new).with(dc_config).
          once.and_return(dc)

      resources = VSphereCloud::Resources.new
      resources.datacenters.should == {"foo" => dc}
      resources.datacenters.should == {"foo" => dc}
    end

    it "should flush stale cached datacenters" do
      vcenter_config = double(:vcenter_config)
      VSphereCloud::Config.vcenter = vcenter_config
      dc_config = double(:dc_config)
      dc_config.stub(:name).and_return("foo")
      vcenter_config.stub(:datacenters).and_return({"foo" => dc_config})
      dc = double(:dc)
      VSphereCloud::Resources::Datacenter.should_receive(:new).with(dc_config).
          twice.and_return(dc)

      now = Time.now.to_i
      Time.should_receive(:now).and_return(now, now, now + 120, now + 120)

      resources = VSphereCloud::Resources.new
      resources.datacenters.should == {"foo" => dc}
      resources.datacenters.should == {"foo" => dc}
    end
  end

  describe :persistent_datastore do
    it "should return the persistent datastore" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      datastore = double(:datastore)
      cluster.stub(:persistent).with("baz").and_return(datastore)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})
      resources.persistent_datastore("foo", "bar", "baz").should == datastore
      resources.persistent_datastore("foo", "ba", "baz").should be_nil
    end
  end

  describe :validate_persistent_datastore do
    it "should return true if the provided datastore is still persistent" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      datastore = double(:datastore)
      cluster.stub(:persistent).with("baz").and_return(datastore)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})
      resources.validate_persistent_datastore("foo", "baz").should be(true)
    end

    it "should return false if the provided datastore is not persistent" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      cluster.stub(:persistent).with("baz").and_return(nil)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})
      resources.validate_persistent_datastore("foo", "baz").should be(false)
    end
  end

  describe :place_persistent_datastore do
    it "should return the datastore when it was placed successfully" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      datastore = double(:datastore)
      datastore.should_receive(:allocate).with(1024)
      cluster.should_receive(:pick_persistent).with(1024).and_return(datastore)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})
      resources.place_persistent_datastore("foo", "bar", 1024).
          should == datastore
    end

    it "should return nil when it wasn't placed successfully" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      cluster.should_receive(:pick_persistent).with(1024).and_return(nil)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})
      resources.place_persistent_datastore("foo", "bar", 1024).
          should be_nil
    end
  end

  describe :place do
    it "should allocate memory and ephemeral disk space" do
      dc = double(:dc)
      cluster = double(:cluster)
      dc.stub(:clusters).and_return({"bar" => cluster})
      datastore = double(:datastore)
      cluster.stub(:name).and_return("bar")
      cluster.stub(:persistent).with("baz").and_return(datastore)
      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})

      scorer = double(:scorer)
      scorer.should_receive(:score).and_return(4)
      VSphereCloud::Resources::Scorer.should_receive(:new).
          with(cluster, 512, 1024, []).and_return(scorer)

      cluster.should_receive(:allocate).with(512)
      cluster.should_receive(:pick_ephemeral).with(1024).and_return(datastore)
      datastore.should_receive(:allocate).with(1024)

      resources.place(512, 1024, []).should == [cluster, datastore]
    end

    it "should prioritize persistent locality" do
      dc = double(:dc)
      cluster_a = double(:cluster_a)
      cluster_b = double(:cluster_b)
      dc.stub(:clusters).and_return({"a" => cluster_a, "b" => cluster_b})

      datastore_a = double(:datastore_a)
      cluster_a.stub(:name).and_return("ds_a")
      cluster_a.stub(:persistent).with("ds_a").and_return(datastore_a)
      cluster_a.stub(:persistent).with("ds_b").and_return(nil)

      datastore_b = double(:datastore_b)
      cluster_b.stub(:name).and_return("ds_b")
      cluster_b.stub(:persistent).with("ds_a").and_return(nil)
      cluster_b.stub(:persistent).with("ds_b").and_return(datastore_b)

      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})

      scorer_b = double(:scorer_a)
      scorer_b.should_receive(:score).and_return(4)
      VSphereCloud::Resources::Scorer.should_receive(:new).
          with(cluster_b, 512, 1024, [2048]).and_return(scorer_b)

      cluster_b.should_receive(:allocate).with(512)
      cluster_b.should_receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
      datastore_b.should_receive(:allocate).with(1024)

      resources.place(512, 1024,
                      [{:size => 2048, :dc_name => "foo", :ds_name => "ds_a"},
                       {:size => 4096, :dc_name => "foo", :ds_name => "ds_b"}]).
          should == [cluster_b, datastore_b]
    end

    it "should ignore locality when there is no space" do
      dc = double(:dc)
      cluster_a = double(:cluster_a)
      cluster_b = double(:cluster_b)
      dc.stub(:clusters).and_return({"a" => cluster_a, "b" => cluster_b})

      datastore_a = double(:datastore_a)
      cluster_a.stub(:name).and_return("ds_a")
      cluster_a.stub(:persistent).with("ds_a").and_return(datastore_a)
      cluster_a.stub(:persistent).with("ds_b").and_return(nil)

      datastore_b = double(:datastore_b)
      cluster_b.stub(:name).and_return("ds_b")
      cluster_b.stub(:persistent).with("ds_a").and_return(nil)
      cluster_b.stub(:persistent).with("ds_b").and_return(datastore_b)

      resources = VSphereCloud::Resources.new
      resources.stub(:datacenters).and_return({"foo" => dc})

      scorer_a = double(:scorer_a)
      scorer_a.should_receive(:score).twice.and_return(0)
      VSphereCloud::Resources::Scorer.should_receive(:new).
          with(cluster_a, 512, 1024, []).twice.and_return(scorer_a)

      scorer_b = double(:scorer_b)
      scorer_b.should_receive(:score).and_return(4)
      VSphereCloud::Resources::Scorer.should_receive(:new).
          with(cluster_b, 512, 1024, [2048]).and_return(scorer_b)

      cluster_b.should_receive(:allocate).with(512)
      cluster_b.should_receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
      datastore_b.should_receive(:allocate).with(1024)

      resources.place(512, 1024,
                      [{:size => 2048, :dc_name => "foo", :ds_name => "ds_a"}]).
          should == [cluster_b, datastore_b]
    end
  end
end
