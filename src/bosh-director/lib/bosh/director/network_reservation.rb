module Bosh::Director
  class NetworkReservation
    attr_reader :ip, :instance_model, :network, :type

    def initialize(instance_model, network)
      @instance_model = instance_model
      @network = network
      @ip = nil
    end

    def static?
      type == :static
    end

    def dynamic?
      type == :dynamic
    end
  end

  class ExistingNetworkReservation < NetworkReservation
    attr_reader :network_type, :obsolete

    def initialize(instance_model, network, ip, network_type)
      super(instance_model, network)
      @ip = IpAddrOrCidr.new(ip) if ip
      @network_type = network_type
      @obsolete = network.instance_of? Bosh::Director::DeploymentPlan::Network
    end

    def resolve_type(type)
      @type = type
    end

    def desc
      "existing reservation#{@ip.nil? ? '' : " with IP '#{@ip}' for instance #{@instance_model}"}"
    end

    def to_s
      "{ip=#{@ip}, network=#{@network.name}, instance=#{@instance_model}, type=#{type}}"
    end
  end

  class DesiredNetworkReservation < NetworkReservation
    def self.new_dynamic(instance_model, network)
      new(instance_model, network, nil, :dynamic)
    end

    def self.new_static(instance_model, network, ip)
      cidr_ip = "#{IpAddrOrCidr.new(ip).base_addr}/#{network.prefix}"
      new(instance_model, network, cidr_ip, :static)
    end

    def initialize(instance_model, network, ip, type)
      super(instance_model, network)
      @ip = resolve_ip(ip) if ip
      @type = type
    end

    def resolve_ip(ip)
      @ip = IpAddrOrCidr.new(ip)
    end

    def resolve_type(type)
      if @type != type
        raise NetworkReservationWrongType,
          "IP '#{@ip}' on network '#{@network.name}' does not belong to #{@type} pool"
      end

      @type = type
    end

    def desc
      "#{type} reservation with IP '#{@ip}' for instance #{@instance_model}"
    end

    def to_s
      "{type=#{type}, ip=#{@ip}, network=#{@network.name}, instance=#{@instance_model}}"
    end
  end
end
