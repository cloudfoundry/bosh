# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class InstanceNetwork
      include IpUtil

      attr_accessor :instance
      attr_accessor :name
      attr_accessor :ip
      attr_accessor :reserved

      def initialize(instance, name)
        @instance = instance
        @name = name
        @ip = nil
        @reserved = false
      end

      def use_reservation(ip, static)
        ip = ip_to_i(ip)
        if @ip
          if @ip == ip && static
            @reserved = true
          end
        elsif !static
          @ip = ip
          @reserved = true
        end
      end
    end
  end
end
