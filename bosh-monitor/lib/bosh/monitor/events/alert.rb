module Bosh::Monitor
  module Events
    class Alert < Base

      # Considering Bosh::Agent::Alert
      SEVERITY_MAP = {
        1 => :alert,
        2 => :critical,
        3 => :error,
        4 => :warning,
        -1 => :ignored
      }

      attr_reader :created_at, :source, :title

      def initialize(attributes = {})
        super
        @kind = :alert

        @id         = @attributes["id"]
        @severity   = @attributes["severity"]
        @title      = @attributes["title"]
        @summary    = @attributes["summary"] || @title
        @source     = @attributes["source"]

        # This rescue is just to preserve existing test behavior. However, this
        # seems like a pretty wacky way to handle errors - wouldn't we rather
        # have a nice exception?
        @created_at = Time.at(@attributes["created_at"]) rescue @attributes["created_at"]
      end

      def validate
        add_error("id is missing") if @id.nil?
        add_error("severity is missing") if @severity.nil?

        if @severity && (!@severity.kind_of?(Integer) || @severity < 0)
          add_error("severity is invalid (non-negative integer expected)")
        end

        add_error("title is missing") if @title.nil?
        add_error("timestamp is missing") if @created_at.nil?

        if @created_at && !@created_at.kind_of?(Time)
          add_error('created_at is invalid UNIX timestamp')
        end
      end

      def short_description
        "Severity #{@severity}: #{@source} #{@title}"
      end

      def severity
        SEVERITY_MAP[@severity] || @severity
      end

      def to_hash
        {
          :kind       => "alert",
          :id         => @id,
          :severity   => @severity,
          :title      => @title,
          :summary    => @summary,
          :source     => @source,
          :created_at => @created_at.to_i
        }
      end

      def to_json
        Yajl::Encoder.encode(self.to_hash)
      end

      def to_s
        "Alert @ #{@created_at.utc}, severity #{@severity}: #{@summary}"
      end

      def to_plain_text
        result = ""
        result << "#{@source}\n" unless @source.nil?
        result << (@title || "Unknown Alert") << "\n"
        result << "Severity: #{@severity}\n"
        result << "Summary: #{@summary}\n" unless @summary.nil?
        result << "Time: #{@created_at.utc}\n"
        result
      end

      def metrics
        [ ]
      end

    end
  end
end
