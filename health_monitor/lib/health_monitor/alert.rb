module Bosh::HealthMonitor

  class Alert

    attr_reader :id
    attr_reader :severity
    attr_reader :summary
    attr_reader :title
    attr_reader :source
    attr_reader :created_at

    attr_reader :errors

    # This is expected to be a primary interface for alert creation.
    # Client code is expected to catch an exception and recover in
    # whatever way it finds convenient. If client code doesn't want
    # to use #create! method it can always perform validation on its own.
    def self.create!(attrs)
      unless attrs.kind_of?(Hash)
        raise InvalidAlert, "Cannot create alert from #{attrs.class}"
      end
      alert = new(attrs)
      unless alert.valid?
        raise InvalidAlert, "Alert is invalid: %s" % [ alert.errors.join(", ") ]
      end
      alert
    end

    def initialize(attrs = {})
      # Stringify keys
      attrs.dup.each_pair do |k, v|
        attrs[k.to_s] = attrs[k]
      end

      @id         = attrs["id"]
      @severity   = attrs["severity"].to_i
      @title      = attrs["title"]
      @summary    = attrs["summary"]
      @source     = attrs["source"]
      @created_at = Time.at(attrs["created_at"]) rescue attrs["created_at"]
    end

    def valid?
      @errors = [ ]
      @errors << "id is missing" if @id.nil?

      unless @severity.kind_of?(Integer) && @severity >= 0
        @errors << "severity is invalid (non-negative integer expected)"
      end

      @errors << "title is missing" if @title.nil?
      @errors << "timestamp is missing" if @created_at.nil?

      if @created_at && !@created_at.kind_of?(Time)
        @errors << "timestamp format is invalid, Time expected"
      end

      @errors.empty?
    end

  end

end
