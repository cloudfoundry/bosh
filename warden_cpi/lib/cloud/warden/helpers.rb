module Bosh::WardenCloud

  module Helpers

    def cloud_error(error)
      unless error.instance_of? Bosh::Clouds::CloudError
        error = Bosh::Clouds::CloudError.new error
      end

      @logger.error(error.message) if @logger
      raise error
    end

  end
end
