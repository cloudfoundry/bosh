require 'logging/filter'

module Bosh::Director
  class RegexLoggingFilter < ::Logging::Filter
    def self.null_query_filter
      new(
        [
          { /^\(\d+\.\d+s\) \(conn: \d+\) SELECT NULL$/ => nil },
        ],
      )
    end

    def self.query_redaction_filter
      new(
        [
          { /^(\(\d+\.\d+s\) \(conn: \d+\) (INSERT INTO ("|`).*?("|`)|UPDATE ("|`).*?("|`)|DELETE FROM ("|`).*?("|`))).+/m => '\1 <redacted>' },
        ],
      )
    end

    def initialize(filters)
      super()
      @filters = filters
    end

    def allow(event)
      @filters.each do |hash|
        match_pattern, replacement_pattern = hash.first

        if replacement_pattern.nil?
          return nil if match_pattern.match?(event.data)
        else
          event.data = event.data.gsub(match_pattern, replacement_pattern)
        end
      end

      event
    end
  end
end
