module Bosh::Director
  class NetworkReservation
    include IpUtil

    attr_reader :ip, :instance, :network, :type

    def initialize(instance, network)
      @instance = instance
      @network = network
      @ip = nil
      @reserved = false
    end

    def resolve_network(network)
      @network = network
    end

    def reserved?
      @reserved
    end

    def mark_reserved
      @reserved = true
    end

    def static?
      type == :static
    end

    def dynamic?
      type == :dynamic
    end

    private

    def formatted_ip
      @ip.nil? ? nil : ip_to_netaddr(@ip).ip
    end
  end

  class ExistingNetworkReservation < NetworkReservation
    attr_reader :network_type

    def initialize(instance, network, ip, network_type)
      super(instance, network)
      @ip = ip_to_i(ip) if ip
      @network_type = network_type
    end

    def resolve_type(type)
      @type = type
    end

    def desc
      "existing reservation#{@ip.nil? ? '' : " with IP '#{formatted_ip}' for instance #{@instance}"}"
    end

    def to_s
      "{ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}, reserved=#{reserved?}, type=#{type}}"
    end
  end

  class DesiredNetworkReservation < NetworkReservation
    def self.new_dynamic(instance, network)
      new(instance, network, nil, :dynamic)
    end

    def self.new_static(instance, network, ip)
      new(instance, network, ip, :static)
    end

    def initialize(instance, network, ip, type)
      @instance = instance
      @network = network
      @ip = ip_to_i(ip) if ip
      @type = type
    end

    def resolve_ip(ip)
      @ip = ip_to_i(ip)
    end

    def resolve_type(type)
      if @type != type
        raise NetworkReservationWrongType,
          "IP '#{formatted_ip}' on network '#{@network.name}' does not belong to #{@type} pool"
      end

      @type = type
    end

    def desc
      "#{type} reservation with IP '#{formatted_ip}' for instance #{@instance}"
    end

    def to_s
      "{type=#{type}, ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance}}"
    end
  end
end
