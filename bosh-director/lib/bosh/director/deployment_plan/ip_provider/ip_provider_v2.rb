module Bosh::Director::DeploymentPlan
  class IpProviderV2
    def initialize(ip_repo)
      @ip_repo = ip_repo
    end

    def delete(ip, network)
      @ip_repo.delete(ip, network)
    end
  end

  class IpRepoThatDelegatesToExistingStuff
    # TODO: we're going to rewrite this once to be more clear once everything has moved inside of it
    def delete(ip, network)
      # FIXME: this should really only need a subnet, not the whole network
      network.release(LiteReservation.new(ip))
    end

    # so the Network is happy
    class LiteReservation < Struct.new(:ip)
    end
  end
end
