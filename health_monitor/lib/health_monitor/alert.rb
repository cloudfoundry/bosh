module Bosh::HealthMonitor

  class Alert

    attr_reader :id
    attr_reader :severity
    attr_reader :title
    attr_reader :summary
    attr_reader :created_at

    attr_reader :errors

    # This is expected to be a primary interface for alert creation.
    # Client code is expected to catch an exception and recover in
    # whatever way it finds convenient. If client code doesn't want
    # to use #create! method it can always perform validation on its own.
    def self.create!(attrs)
      alert = new(attrs)
      unless alert.valid?
        raise InvalidAlert, "Alert is invalid: %s" % [ alert.errors.join(", ") ]
      end
      alert
    end

    def initialize(attrs = {})
      @id         = attrs[:id]
      @severity   = attrs[:severity]
      @title      = attrs[:title]
      @summary    = attrs[:summary]
      @created_at = attrs[:created_at]
    end

    def valid?
      @errors = [ ]
      @errors << "id is missing" if @id.nil?
      @errors << "severity is invalid (integer expected)" unless @severity.kind_of?(Integer)
      @errors << "title is missing" if @title.nil?
      @errors << "timestamp is missing" if @created_at.nil?

      @errors.empty?
    end

  end

end
