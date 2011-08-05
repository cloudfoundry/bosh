module Bosh::HealthMonitor

  class Event

    attr_reader :timestamp
    attr_reader :summary
    attr_reader :data

    attr_reader :errors

    def self.create!(attrs)
      unless attrs.kind_of?(Hash)
        raise InvalidEvent, "Cannot create event from #{attrs.class}"
      end
      event = new(attrs)
      unless event.valid?
        raise InvalidEvent, "Event is invalid: %s" % [ event.errors.join(", ") ]
      end
      event
    end

    def initialize(attrs = { })
      # Stringify keys
      attrs.dup.each_pair do |k, v|
        attrs[k.to_s] = attrs[k]
      end

      @timestamp = attrs["timestamp"]
      @summary   = attrs["summary"]
      @data      = attrs["data"]
    end

    def valid?
      @errors = [ ]
      @errors << "timestamp is missing" if @timestamp.nil?
      @errors << "summary is missing" if @summary.nil?

      if @timestamp && !@timestamp.kind_of?(Integer)
        @errors << "timestamp format is invalid, Unix timestamp expected"
      end

      @errors.empty?
    end

    def to_json
      payload = {
        :timestamp => @timestamp,
        :summary   => @summary,
        :data      => @data
      }
      Yajl::Encoder.encode(payload)
    end

  end

end
