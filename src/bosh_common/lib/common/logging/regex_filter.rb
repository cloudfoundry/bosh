require 'logging/filter'

module Bosh
  module Common
    module Logging
      class RegexFilter < ::Logging::Filter
        def initialize(filters)
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
  end
end
