module Bosh::Director
  class NetworkReservation
    include IpUtil

    attr_reader :ip, :instance, :network

    def initialize(instance, network)
      @instance = instance
      @network = network
      @ip = nil
      @reserved = false
    end

    def reserved?
      @reserved
    end

    private

    def formatted_ip
      @ip.nil? ? nil : ip_to_netaddr(@ip).ip
    end
  end

  class StaticNetworkReservation < NetworkReservation
    def initialize(instance, network, ip)
      super(instance, network)
      @ip = ip_to_i(ip)
    end

    def desc
      "static reservation with IP '#{formatted_ip}'"
    end

    def to_s
      "{type=static, ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}}"
    end

    def mark_reserved_as(type)
      if type != self.type
        raise NetworkReservationWrongType,
          "IP '#{format_ip(@ip)}' on network '#{@network.name}' does not belong to static pool"
      end

      @reserved = true
    end

    def type
      StaticNetworkReservation
    end
  end

  #TODO: Rename DynamicNetworkReservation to something more logical
  # DynamicNetworkReservation is the network reservation for BOSH manual networks with dynamic ip reservation
  class DynamicNetworkReservation < NetworkReservation
    def resolve_ip(ip)
      @ip = ip_to_i(ip)
    end

    def desc
      "dynamic reservation#{@ip.nil? ? '' : " with IP '#{formatted_ip}'"}"
    end

    def to_s
      "{type=dynamic, ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}}"
    end

    def mark_reserved_as(type)
      if type != self.type
        raise NetworkReservationWrongType,
          "IP '#{format_ip(@ip)}' on network '#{@network.name}' does not belong to dynamic pool"
      end

      @reserved = true
    end

    def type
      DynamicNetworkReservation
    end
  end

  class ExistingNetworkReservation < NetworkReservation
    def initialize(instance, network, ip)
      super(instance, network)
      @ip = ip_to_i(ip) if ip
    end

    def reserved_as?(type)
      @reserved && @reserved_as == type
    end

    def reserved_as
      @reserved_as
    end

    def mark_reserved_as(type)
      @reserved_as = type
      @reserved = true
    end

    def desc
      "existing reservation#{@ip.nil? ? '' : " with IP '#{formatted_ip}'"}"
    end

    def to_s
      "{ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}}"
    end
  end
end
