class FakeCluster < VSphereCloud::Resources::Cluster
  attr_reader :name, :config, :free_memory, :persistent_datastores, :ephemeral_datastores

  def initialize(name, datastores, free_memory = 1024)
    @name = name
    config = Struct.new(:name)
    @config = config.new(name)
    @datastores = datastores
    @free_memory = free_memory

    @ephemeral_datastores = {}
    @persistent_datastores = {}

    datastores.each do |datastore|
      @ephemeral_datastores[datastore.name] = datastore
      @persistent_datastores[datastore.name] = datastore
    end

    @allocated_after_sync = 0
  end
end
