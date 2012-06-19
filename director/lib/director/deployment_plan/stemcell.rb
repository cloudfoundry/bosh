# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class StemcellSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :resource_pool
      attr_accessor :version
      attr_accessor :stemcell

      def initialize(resource_pool, stemcell_spec)
        @resource_pool = resource_pool
        @name = safe_property(stemcell_spec, "name", :class => String)
        @version = safe_property(stemcell_spec, "version", :class => String)
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

      def method_missing(method_name, *args)
        @stemcell.send(method_name, *args)
      end
    end
  end
end