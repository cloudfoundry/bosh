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

      # This method takes in a name of a template or an array of template names
      # and will initialize TemplateSpec classes for each template.  It will
      # then return an array of these TemplateSec classes.
      # @param [String|Array] name_or_array Template name or names.
      # @return [Array] Returns an array of the TemplateSepc classes
      #     initialized to the name_or_array.
      def template(name_or_array)
        name_or_array = [name_or_array] unless name_or_array.is_a?(Array)
        templates = []
        name_or_array.each do |n|
          @templates[n] ||= TemplateSpec.new(n)
          templates.push(@templates[n])
        end
        templates
      end

      def templates
        @templates.values
      end
    end
  end
end