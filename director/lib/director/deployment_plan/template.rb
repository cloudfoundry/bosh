# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class TemplateSpec
      attr_accessor :deployment
      attr_accessor :template
      attr_accessor :name
      attr_accessor :packages

      def initialize(deployment, name)
        @deployment = deployment
        @name = name
      end

      def method_missing(method_name, *args)
        @template.send(method_name, *args)
      end
    end
  end
end