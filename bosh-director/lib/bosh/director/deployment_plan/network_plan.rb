module Bosh::Director::DeploymentPlan
  class NetworkPlan
    # FIXME: this is not a great place for this method
    # FIXME: this relies on instance.add_network_reservation having been called for all desired reservations
    def self.plans_from_instance(instance)
      obsolete_reservations = instance.take_old_reservations
      desired_reservations = instance.network_reservations
      obsolete_network_plans = obsolete_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation, obsolete: true)
      end
      desired_network_plans = desired_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation, obsolete: false)
      end
      desired_network_plans + obsolete_network_plans
    end

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
