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
      @reserved = true
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

    # @param [ExistingNetworkReservation] reservation
    def bind_existing(reservation)
      return unless reservation.instance_of?(ExistingNetworkReservation)
      return unless reservation.reserved?

      return if @ip != reservation.ip

      @reserved = true
    end

    def to_s
      "{type=static, ip=#{formatted_ip.inspect}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}}"
    end

    def validate_type(type_class)
      if type_class != StaticNetworkReservation
        raise NetworkReservationWrongType,
          "IP '#{formatted_ip}' on network '#{@network.name}' does not belong to static pool"
      end
    end
  end

  class DynamicNetworkReservation < NetworkReservation
    # @param [ExistingNetworkReservation] reservation
    def bind_existing(reservation)
      return unless reservation.instance_of?(ExistingNetworkReservation)
      return unless reservation.reserved?

      @ip = reservation.ip
      @reserved = true
    end

    def resolve_ip(ip)
      @ip = ip_to_i(ip)
    end

    def to_s
      "{type=dynamic, ip=#{formatted_ip.inspect}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}}"
    end

    def validate_type(type_class)
      if type_class != DynamicNetworkReservation
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
      # existing reservation now is outside of subnet range,
      # allow to change it until it is bound to either static or dynamic
      @reserved = false
    end

    def validate_type(_)
      true
    end

    def to_s
      "{ip=#{formatted_ip.inspect}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}}"
    end
  end
end
