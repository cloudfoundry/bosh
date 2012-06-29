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

    # @return [Symbol, nil] reservation error
    attr_accessor :error

    def self.new_dynamic(ip = nil)
      new(:type => NetworkReservation::DYNAMIC, :ip => ip)
    end

    def self.new_static(ip = nil)
      new(:type => NetworkReservation::STATIC, :ip => ip)
    end

    ##
    # Creates a new network reservation
    # @param [Hash] options the options to create the reservation from
    # @option options [Integer, String, NetAddr::CIDR] :ip reservation ip
    # @option options [Symbol] :type reservation type
    def initialize(options = {})
      @ip = options[:ip]
      @type = options[:type]
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

    ##
    # Handles network reservation error and re-raises the proper exception
    # @param [String] origin Whoever tried to take the reservation
    # @raise [NetworkReservationAlreadyInUse]
    # @raise [NetworkReservationWrongType]
    # @raise [NetworkReservationNotEnoughCapacity]
    # @raise [NetworkReservationError]
    # @return void
    def handle_error(origin)
      if static?
        formatted_ip = ip_to_netaddr(@ip).ip
        case @error
          when NetworkReservation::USED
            raise NetworkReservationAlreadyInUse,
                  "#{origin} asked for a static IP #{formatted_ip} " +
                  "but it's already reserved/in use"
          when NetworkReservation::WRONG_TYPE
            raise NetworkReservationWrongType,
                  "#{origin} asked for a static IP #{formatted_ip} " +
                  "but it's in the dynamic pool"
          else
            raise NetworkReservationError,
                  "#{origin} failed to reserve static IP " +
                  "#{formatted_ip}: #{@error}"
        end
      else
        case @error
          when NetworkReservation::CAPACITY
            raise NetworkReservationNotEnoughCapacity,
                  "#{origin} asked for a dynamic IP " +
                  "but there were no more available"
          else
            raise NetworkReservationError,
                  "#{origin} failed to reserve dynamic IP " +
                  "#{formatted_ip}: #{@error}"
        end
      end
    end
  end
end