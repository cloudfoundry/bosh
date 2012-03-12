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

    ##
    # Creates a new network reservation
    # @param [Hash] options the options to create the reservation from
    # @option options [Integer, String, NetAddr::CIDR] :ip reservation ip
    # @option options [Symbol] :type reservation type
    def initialize(options = {})
      @ip = options[:ip]
      @type = options[:type]
      @reserved = false

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
  end
end