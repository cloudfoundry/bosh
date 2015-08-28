module Bosh::Director::DeploymentPlan
  class NetworkPlan
    def initialize(attrs)
      @reservation = attrs.fetch(:reservation)
      @obsolete = attrs.fetch(:obsolete, false)
    end

    attr_reader :reservation

    def obsolete?
      !!@obsolete
    end
  end
end
