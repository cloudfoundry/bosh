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

    # @return [Boolean] reserved
    attr_accessor :reserved

    attr_reader :instance

    def self.new_dynamic(instance)
      new(instance, nil, NetworkReservation::DYNAMIC)
    end

    def self.new_static(instance, ip)
      new(instance, ip, NetworkReservation::STATIC)
    end

    # network reservation for existing instance
    # type is ignored in validation and will be set from network
    def self.new_unresolved(instance, ip)
      new(instance, ip, nil)
    end

    ##
    # Creates a new network reservation
    # @param [DeploymentPlan::Instance] instance
    # @param [Integer, String, NetAddr::CIDR] ip reservation ip
    # @param [Symbol] type of reservation
    def initialize(instance, ip, type)
      @instance = instance
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

    ##
    # Tries to take the provided reservation if it meets the requirements
    # @return [void]
    def take(other)
      if other.reserved?
        if @type == other.type
          if dynamic? || (static? && @ip == other.ip)
            @ip = other.ip
            @reserved = true
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
