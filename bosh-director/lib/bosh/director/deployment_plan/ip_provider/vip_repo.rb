module Bosh::Director::DeploymentPlan
  class VipRepo
    include Bosh::Director::IpUtil

    def initialize(logger)
      @logger = logger
      @ips = []
    end

    def add(reservation)
      if @ips.include?(reservation.ip)
        raise Bosh::Director::NetworkReservationAlreadyInUse,
          "Failed to reserve IP '#{format_ip(reservation.ip)}' for vip network '#{reservation.network.name}': IP already reserved"
      end
      @ips << reservation.ip
      @logger.debug("Reserved VIP #{format_ip(reservation.ip)} for vip network '#{reservation.network.name}'")
    end

    def delete(ip, network_name)
      @ips.delete(ip)
      @logger.debug("Released VIP #{format_ip(ip)} for vip network '#{network_name}'")
    end
  end
end

