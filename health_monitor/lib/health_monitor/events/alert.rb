module Bosh::HealthMonitor
  module Events
    class Alert < Base
      def initialize(attributes = {})
        super
        @kind = :alert

        @id         = @attributes["id"]
        @severity   = @attributes["severity"]
        @title      = @attributes["title"]
        @summary    = @attributes["summary"] || @title
        @source     = @attributes["source"]
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
          add_error("timestamp is invalid")
        end
      end

      def short_description
        "Severity #{@severity}: #{@source} #{@title}"
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
