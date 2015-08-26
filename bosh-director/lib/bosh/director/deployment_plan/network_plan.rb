module Bosh::Director::DeploymentPlan
  class NetworkPlan
    def initialize(attrs)
      @ip = attrs.fetch(:ip)
      @network = attrs.fetch(:network)
      @obsolete = attrs.fetch(:obsolete, false)
    end

    attr_reader :ip, :network

    def obsolete?
      !!@obsolete
    end
  end
end
