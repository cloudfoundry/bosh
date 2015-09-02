module Bosh::AwsCloud
  ##
  #
  class ManualNetwork < Network

    attr_reader :subnet

    # create manual network
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
      if @cloud_properties.nil? || !@cloud_properties.has_key?("subnet")
        raise Bosh::Clouds::CloudError, "subnet required for manual network"
      end
      @subnet = @cloud_properties["subnet"]
    end

    def private_ip
      @ip
    end

    def configure(ec2, instance)
    end
  end
end