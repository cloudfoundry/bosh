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

    def reserve
      @network.reserve(self)
    end

    def release
      @network.release(self)
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

    # @param [ExistingNetworkReservation] other
    def bind_existing(other)
      return unless other.instance_of?(ExistingNetworkReservation)
      return unless other.reserved_as?(StaticNetworkReservation)

      return if @ip != other.ip

      @reserved = true
    end

    def desc
      "static reservation with IP '#{formatted_ip}'"
    end

    def to_s
      "{type=static, ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}}"
    end

    def mark_reserved_as(type)
      validate_type(type)
      @reserved = true
    end

    def validate_type(type)
      if type != StaticNetworkReservation
        raise NetworkReservationWrongType,
          "IP '#{formatted_ip}' on network '#{@network.name}' does not belong to static pool"
      end
    end
  end

  #TODO: Rename DynamicNetworkReservation to something more logical
  # DynamicNetworkReservation is the network reservation for BOSH manual networks with dynamic ip reservation
  class DynamicNetworkReservation < NetworkReservation
    # @param [ExistingNetworkReservation] other
    def bind_existing(other)
      return unless other.instance_of?(ExistingNetworkReservation)
      return unless other.reserved_as?(DynamicNetworkReservation)

      @ip = other.ip
      @reserved = true
    end

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
      validate_type(type)
      @reserved = true
    end

    def validate_type(type)
      if type != DynamicNetworkReservation
        raise NetworkReservationWrongType,
          "IP '#{formatted_ip}' on network '#{@network.name}' does not belong to dynamic pool"
      end
    end
  end

  class ExistingNetworkReservation < NetworkReservation
    def initialize(instance, network, ip)
      super(instance, network)
      @ip = ip_to_i(ip) if ip
    end

    def reserve
      super
    rescue NetworkReservationIpOutsideSubnet, NetworkReservationIpReserved
      # existing reservation now is outside of subnet range or in reserved range,
      # allow to change or release it
    end

    def reserved_as?(type)
      @reserved && @reserved_as == type
    end

    def mark_reserved_as(type)
      @reserved_as = type
      @reserved = true
    end

    def validate_type(_)
      true
    end

    def to_s
      "{ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}}"
    end
  end
end
