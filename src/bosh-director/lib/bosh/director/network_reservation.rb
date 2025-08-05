module Bosh::Director
  class NetworkReservation
    attr_reader :ip, :instance_model, :network, :type, :nic_group

    def initialize(instance_model, network, nic_group)
      @instance_model = instance_model
      @network = network
      @ip = nil
      @nic_group = nic_group.to_i if nic_group
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

    def initialize(instance_model, network, ip, network_type, nic_group = nil)
      super(instance_model, network, nic_group)
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
    def self.new_dynamic(instance_model, network, nic_group = nil)
      new(instance_model, network, nil, :dynamic, nic_group)
    end

    def self.new_static(instance_model, network, ip, nic_group = nil)
      cidr_ip = "#{IpAddrOrCidr.new(ip).base_addr}/#{network.prefix}"
      new(instance_model, network, cidr_ip, :static, nic_group)
    end

    def initialize(instance_model, network, ip, type, nic_group)
      super(instance_model, network, nic_group)
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
