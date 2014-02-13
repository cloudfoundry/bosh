module VSphereCloud
  class ClusterConfig

    attr_reader :name

    def initialize(name, config_hash)
      @name = name
      @config = config_hash
    end

    def resource_pool
      @config['resource_pool']
    end
  end
end
