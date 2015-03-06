require 'spec_helper'

describe VSphereCloud::Resources::Scorer do
  let(:logger) { instance_double('Logger', debug: nil, info: nil ) }

  def create_datastores(sizes)
    datastores = {}
    sizes.each_with_index do |size, i|
      datastore = double(:datastore)
      allow(datastore).to receive(:free_space).and_return(size)
      datastores["ds_#{i}"] = datastore
    end
    datastores
  end

  def create_cluster(memory, ephemeral, persistent)
    cluster = double(:cluster)
    allow(cluster).to receive(:name).and_return("foo")
    allow(cluster).to receive(:free_memory).and_return(memory)
    allow(cluster).to receive(:ephemeral_datastores).
        and_return(create_datastores(ephemeral))
    allow(cluster).to receive(:persistent_datastores).
        and_return(create_datastores(persistent))
    cluster
  end

  describe :score do
    it "should return 0 when memory is not available" do
      cluster = create_cluster(500, [32 * 1024], [32 * 1024])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 512, 1, [])).to eq(0)
    end

    it "should return 0 when ephemeral space is not available" do
      cluster = create_cluster(16 * 1024, [512], [32 * 1024])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 1, 1024, [])).to eq(0)
    end

    it "should return 0 when persistent space is not available" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [512])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 1, 1, [1024])).to eq(0)
    end

    it "should calculate memory bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 512, 1, [])).to eq(31)
    end

    it "should calculate ephemeral bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 1, 512, [])).to eq(62)
    end

    it "should calculate persistent bound score" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [32 * 1024])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 1, 1, [512])).to eq(62)
    end

    it "should calculate score for required disk sizes" do
      cluster = create_cluster(16 * 1024, [32 * 1024], [22 * 512])
      expect(VSphereCloud::Resources::Scorer.score(logger, cluster, 1, 1024, [512])).to eq(20)
    end
  end
end
