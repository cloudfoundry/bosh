# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud
  ##
  #
  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures vip network
    #
    # @param [AWS:EC2] ec2 EC2 client
    # @param [AWS::EC2::Instance] instance EC2 instance to configure
    def configure(ec2, instance)
      if @ip.nil?
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      elastic_ip = ec2.elastic_ips[@ip]
      @logger.info("Associating instance `#{instance.id}' " \
                   "with elastic IP `#{elastic_ip}'")

      # New elastic IP reservation supposed to clear the old one,
      # so no need to disassociate manually. Also, we don't check
      # if this IP is actually an allocated EC2 elastic IP, as
      # API call will fail in that case.

      retry_until_ready do
        instance.associate_elastic_ip(elastic_ip)
      end
    end

    def retry_until_ready
      task_checkpoint
      yield
    rescue AWS::EC2::Errors::IncorrectInstanceState => e
      @logger.warn("not ready yet: #{e.message}")
      sleep(1)
      # should we have a limited number of retries?
      retry
    end
  end
end


