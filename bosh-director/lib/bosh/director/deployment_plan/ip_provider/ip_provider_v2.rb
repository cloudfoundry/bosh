module Bosh::Director::DeploymentPlan
  class IpProviderV2
    def initialize(ip_repo)
      @ip_repo = ip_repo
    end

    def release(reservation)
      @ip_repo.delete(reservation)
    end

    def reserve(reservation)
      @ip_repo.create(reservation)
    end
  end

  class IpRepoThatDelegatesToExistingStuff
    # TODO: we're going to rewrite this to be more clear once everything has moved inside of it
    def delete(reservation)
      reservation.network.release(reservation)
    end

    def create(reservation)
      # FIXME: this should really only need a subnet, not the whole network
      reservation.network.reserve(reservation)
    end
  end
end
