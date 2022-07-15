module Bosh::Director
  class NetworkReservation
    include IpUtil

    attr_reader :ip, :version, :instance_model, :network, :type

    def initialize(instance_model, network)
      @instance_model = instance_model
      @network = network
      @ip = nil
      @version = nil
    end

    def static?
      type == :static
    end

    def dynamic?
      type == :dynamic
    end

    private

    def formatted_ip
      @ip.nil? ? nil : ip_to_netaddr(@ip, @version).ip
    end
  end

  class ExistingNetworkReservation < NetworkReservation
    attr_reader :network_type, :obsolete

    def initialize(instance_model, network, ip, network_type)
      super(instance_model, network)
      @network_type = network_type
      @obsolete = network.instance_of? Bosh::Director::DeploymentPlan::Network
      if ip
        cidr_ip = ip_to_netaddr(ip)
        @ip = cidr_ip.to_i
        @version = cidr_ip.version
      end
    end

    def resolve_type(type)
      @type = type
    end

    def desc
      "existing reservation#{@ip.nil? ? '' : " with IP '#{formatted_ip}' for instance #{@instance_model}"}"
    end

    def to_s
      "{ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance_model}, type=#{type}}"
    end
  end

  class DesiredNetworkReservation < NetworkReservation
    def self.new_dynamic(instance_model, network)
      new(instance_model, network, nil, :dynamic)
    end

    def self.new_static(instance_model, network, ip)
      new(instance_model, network, ip, :static)
    end

    def initialize(instance_model, network, ip, type)
      super(instance_model, network)
      @type = type
      if ip
        cidr_ip = ip_to_netaddr(ip)
        @ip = cidr_ip.to_i
        @version = cidr_ip.version
      end
    end

    def resolve_ip(ip)
      # TODO: IPv6 should also set @version, but is sometimes called with int, sometimes with IPAddr and sometimes with string
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
      "#{type} reservation with IP '#{formatted_ip}' for instance #{@instance_model}"
    end

    def to_s
      "{type=#{type}, ip=#{formatted_ip}, network=#{@network.name}, instance=#{@instance_model}}"
    end
  end
end
