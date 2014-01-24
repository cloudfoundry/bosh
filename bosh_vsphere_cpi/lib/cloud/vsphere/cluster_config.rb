module VSphereCloud
  class ClusterConfig

    attr_reader :name

    def initialize(name, config)
      @name = name
      @config = config
    end

    def resource_pool
      @config['resource_pool']
    end

  end
end
