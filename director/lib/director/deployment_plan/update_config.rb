# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class UpdateConfig
      # TODO: it would be nice if update config was aware of which job
      # it related to to properly format error messages
      include ValidationHelper

      attr_accessor :canaries
      attr_accessor :max_in_flight

      attr_accessor :min_canary_watch_time
      attr_accessor :max_canary_watch_time

      attr_accessor :min_update_watch_time
      attr_accessor :max_update_watch_time

      # @param [Hash] update_config Raw update config from deployment manifest
      # @param [optional, Hash] default_update_config Default update config
      def initialize(update_config, default_update_config = nil)
        optional = !default_update_config.nil?

        @canaries = safe_property(update_config, "canaries",
                                  :class => Integer, :optional => optional)

        @max_in_flight = safe_property(update_config, "max_in_flight",
                                       :class => Integer, :optional => optional,
                                       :min => 1, :max => 32)

        canary_watch_times = safe_property(update_config, "canary_watch_time",
                                           :class => String,
                                           :optional => optional)
        update_watch_times = safe_property(update_config, "update_watch_time",
                                           :class => String,
                                           :optional => optional)

        if canary_watch_times
          @min_canary_watch_time, @max_canary_watch_time =
            parse_watch_times(canary_watch_times)
        end

        if update_watch_times
          @min_update_watch_time, @max_update_watch_time =
            parse_watch_times(update_watch_times)
        end

        if optional
          @canaries ||= default_update_config.canaries

          @min_canary_watch_time ||= default_update_config.min_canary_watch_time
          @max_canary_watch_time ||= default_update_config.max_canary_watch_time

          @min_update_watch_time ||= default_update_config.min_update_watch_time
          @max_update_watch_time ||= default_update_config.max_update_watch_time

          @max_in_flight ||= default_update_config.max_in_flight
        end
      end

      def parse_watch_times(value)
        value = value.to_s

        if value =~ /^\s*(\d+)\s*\-\s*(\d+)\s*$/
          result = [$1.to_i, $2.to_i]
        elsif value =~ /^\s*(\d+)\s*$/
          result = [$1.to_i, $1.to_i]
        else
          raise UpdateConfigInvalidWatchTime,
                "Watch time should be an integer or a range of two integers"
        end

        if result[0] > result[1]
          raise UpdateConfigInvalidWatchTime,
                "Min watch time cannot be greater than max watch time"
        end

        result
      end
    end
  end
end