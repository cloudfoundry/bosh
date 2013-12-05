module Bosh::AwsCloud
  class LightStemcell
    def initialize(heavy_stemcell, logger)
      @logger = logger
      @heavy_stemcell = heavy_stemcell
    end

    def delete
      @logger.info("NoOP: Deleting light stemcell '#{@heavy_stemcell.id}'")
    end

    def id
      "#{@heavy_stemcell.id} light"
    end

    def root_device_name
      @heavy_stemcell.root_device_name
    end

    def image_id
      @heavy_stemcell.image_id
    end
  end
end
