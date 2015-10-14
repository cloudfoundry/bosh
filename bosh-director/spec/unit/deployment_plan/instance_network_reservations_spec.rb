require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::InstanceNetworkReservations do
    let(:instance_network_reservations) { DeploymentPlan::InstanceNetworkReservations.new(logger) }

    let(:instance) do
      instance_double(DeploymentPlan::Instance, to_s: 'fake-instance')
    end
  end
end
