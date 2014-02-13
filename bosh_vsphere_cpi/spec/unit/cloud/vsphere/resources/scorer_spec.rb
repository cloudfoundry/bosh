require 'spec_helper'

describe VSphereCloud::Resources::Scorer do
  let(:config) { instance_double('VSphereCloud::Config', logger: instance_double('Logger', debug:nil ))}

  def create_datastores(sizes)
    datastores = {}
    sizes.each_with_index do |size, i|
      datastore = double(:datastore)
      datastore.stub(:free_space).and_return(size)
      datastores["ds_#{i}"] = datastore
    end
    datastores
  end

  def create_cluster(memory, ephemeral, persistent, shared)
    cluster = double(:cluster)
    cluster.stub(:name).and_return("foo")
    cluster.stub(:free_memory).and_return(memory)
    cluster.stub(:ephemeral_datastores).
        and_return(create_datastores(ephemeral))
    cluster.stub(:persistent_datastores).
        and_return(create_datastores(persistent))
    cluster.stub(:shared_datastores).
        and_return(create_datastores(shared))
    cluster
  end

  describe :score do
    it "should return 0 when memory is not available" do
      cluster = create_cluster(500, [32 * 1024], [32 * 1024], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 512, 1, [])
      scorer.score.should == 0
    end

    it "should return 0 when ephemeral space is not available" do
      cluster = create_cluster(16 * 1024, [512], [32 * 1024], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 1, 1024, [])
      scorer.score.should == 0
    end

    it "should return 0 when persistent space is not available" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [512], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 1, 1, [1024])
      scorer.score.should == 0
    end

    it "should calculate memory bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 512, 1, [])
      scorer.score.should == 31
    end

    it "should calculate ephemeral bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 1, 512, [])
      scorer.score.should == 62
    end

    it "should calculate persistent bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024], [])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 1, 1, [512])
      scorer.score.should == 62
    end

    it "should calculate shared bound score" do
      cluster = create_cluster(16 * 1024, [], [], [32 * 1024])
      scorer = VSphereCloud::Resources::Scorer.new(config, cluster, 1, 1024, [512])
      scorer.score.should == 20
    end
  end
end
