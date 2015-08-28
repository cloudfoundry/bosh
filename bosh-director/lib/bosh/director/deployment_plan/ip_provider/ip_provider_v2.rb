module Bosh::Director::DeploymentPlan
  class IpProviderV2
    def initialize(ip_repo)
      @ip_repo = ip_repo
    end

    def release(reservation)
      @ip_repo.delete(reservation)
    end
  end

  class IpRepoThatDelegatesToExistingStuff
    # TODO: we're going to rewrite this to be more clear once everything has moved inside of it
    def delete(reservation)
      reservation.network.release(reservation)
    end
  end
end
