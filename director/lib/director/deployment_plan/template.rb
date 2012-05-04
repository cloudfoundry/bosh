# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class TemplateSpec
      attr_reader :name

      attr_accessor :template
      attr_accessor :packages

      # @param [String] name Template name
      def initialize(name)
        @name = name
        @template = nil
        @packages = {}
      end
    end
  end
end