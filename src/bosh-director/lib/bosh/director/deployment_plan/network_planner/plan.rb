module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class Plan
      def initialize(attrs)
        @reservation = attrs.fetch(:reservation)
        @obsolete = attrs.fetch(:obsolete, false)
        @existing = attrs.fetch(:existing, false)
      end

      attr_reader :reservation
      attr_accessor :existing

      def obsolete?
        !!@obsolete
      end

      def desired?
        !existing? && !obsolete?
      end

      def existing?
        !!@existing
      end
    end
  end
end
