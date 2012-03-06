# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class ReleaseSpec
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :version
      attr_accessor :release
      attr_accessor :release_version

      def initialize(deployment, release_spec)
        @deployment = deployment
        @name = safe_property(release_spec, "name", :class => String)
        @version = safe_property(release_spec, "version", :class => String)
      end

      def spec
        {
            "name" => @name,
            "version" => @version
        }
      end
    end
  end
end