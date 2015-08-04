# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  ##
  # Network resolution, either existing or one to be fulfilled by {Network}
  class NetworkReservation
    include IpUtil

    STATIC = :static
    DYNAMIC = :dynamic

    USED = :used
    CAPACITY = :capacity
    WRONG_TYPE = :wrong_type

    # @return [Integer, nil] ip
    attr_accessor :ip

    # @return [Symbol, nil] type
    attr_accessor :type

    attr_reader :instance

    attr_reader :network

    def self.new_dynamic(instance, network)
      new(instance, network, nil, NetworkReservation::DYNAMIC)
    end

    def self.new_static(instance, network, ip)
      new(instance, network, ip, NetworkReservation::STATIC)
    end

    # network reservation for existing instance
    # type is ignored in validation and will be set from network
    def self.new_unresolved(instance, network, ip)
      new(instance, network, ip, nil)
    end

    ##
    # Creates a new network reservation
    # @param [DeploymentPlan::Instance] instance
    # @param [DeploymentPlan::Network] network reservation network
    # @param [Integer, String, NetAddr::CIDR] ip reservation ip
    # @param [Symbol] type of reservation
    def initialize(instance, network, ip, type)
      @instance = instance
      @network = network
      @ip = ip
      @type = type
      @reserved = false
      @error = nil

      @ip = ip_to_i(@ip) if @ip
    end

    ##
    # @return [Boolean] returns true if this is a static reservation
    def static?
      @type == STATIC
    end

    ##
    # @return [Boolean] returns true if this is a dynamic reservation
    def dynamic?
      @type == DYNAMIC
    end

    ##
    # @return [Boolean] returns true if this reservation was fulfilled
    def reserved?
      !!@reserved
    end

    def validate_type(type)
      return unless resolved?

      if @type != type
        ip_desc = @ip.nil? ? 'IP' : "IP '#{formatted_ip}'"

        raise NetworkReservationWrongType,
          "Failed to assign #{@type} #{ip_desc} to '#{@instance}': does not belong to #{format_type(type)} pool"
      end
    end

    # If type is not set, reservation was created from existing
    # instance state. This reservation is considered valid
    # until it is resolved
    def resolved?
      !@type.nil?
    end

    def reserve
      @network.reserve(self)
    end

    def release
      @network.release(self)
    end

    def reserve_with_ip(ip)
      @ip = ip
      mark_as_reserved
    end

    def mark_as_reserved
      @reserved = true
    end

    ##
    # Tries to take the provided reservation if it meets the requirements
    # @return [void]
    def take(other)
      if other.reserved?
        if @type == other.type
          if dynamic? || (static? && @ip == other.ip)
            @ip = other.ip
            mark_as_reserved
          end
        end
      end
    end

    def to_s
      "{type=#{@type}, ip=#{formatted_ip.inspect}}"
    end

    private

    def formatted_ip
      @ip.nil? ? nil : ip_to_netaddr(@ip).ip
    end

    def format_type(type)
      case type
        when NetworkReservation::STATIC
          'static'
        when NetworkReservation::DYNAMIC
          'dynamic'
        else
          type
      end
    end

  end
end
