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

      # @param [Bosh::Director::DeploymentPlan] plan Deployment plan
      # @param [Hash] spec Raw release spec from the deployment
      #   manifest
      def initialize(plan, spec)
        @deployment = plan
        @name = safe_property(spec, "name", :class => String)
        @version = safe_property(spec, "version", :class => String)

        @templates = {}

        # These are to be filled in by deployment plan compiler
        @release = nil
        @release_version = nil
      end

      # @return [Hash] Hash representation
      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

      # @param [String] name Template name
      def template(name)
        @templates[name] ||= TemplateSpec.new(name)
      end

      def templates
        @templates.values
      end
    end
  end
end