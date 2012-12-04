module Bosh::WardenCloud

  module Helpers

    def cloud_error(error)
      unless error.instance_of? Bosh::Clouds::CloudError
        error = Bosh::Clouds::CloudError.new error
      end

      @logger.error(error.message) if @logger
      raise error
    end

    def uuid(klass=nil)
      id = SecureRandom.uuid

      if klass
        id = "%s-%s" % [klass, id]
      end

      id
    end

  end
end
