module Bosh::Director
  module DeploymentPlan
    class UpdateConfig
      STRATEGY_HOT_SWAP = 'duplicate-and-replace-vm'.freeze
      STRATEGY_LEGACY = 'in-place-replace-vm'.freeze
      ALLOWED_STRATEGY = [STRATEGY_HOT_SWAP, STRATEGY_LEGACY].freeze

      include ValidationHelper

      attr_accessor :min_canary_watch_time
      attr_accessor :max_canary_watch_time

      attr_accessor :min_update_watch_time
      attr_accessor :max_update_watch_time

      attr_reader :canaries_before_calculation
      attr_reader :max_in_flight_before_calculation

      attr_reader :strategy

      # @param [Hash] update_config Raw update config from deployment manifest
      # @param [optional, Hash] default_update_config Default update config
      def initialize(update_config, default_update_config = nil)
        optional = !default_update_config.nil?

        @canaries_before_calculation = safe_property(update_config, "canaries",
                                  :class => String, :optional => optional)

        @max_in_flight_before_calculation = safe_property(update_config, "max_in_flight",
                                       :class => String, :optional => optional)

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

        @strategy = safe_property(update_config, 'strategy',
          class: String,
          optional: true,
          default: default_update_config ? default_update_config.strategy : UpdateConfig::STRATEGY_HOT_SWAP, # nil,
        )

        unless @strategy.nil?
          unless UpdateConfig::ALLOWED_STRATEGY.include?(@strategy)
            raise ValidationInvalidValue,
              "Invalid strategy '#{strategy}', valid strategies are: #{UpdateConfig::ALLOWED_STRATEGY.join(', ')}"
          end
        end

        @serial = safe_property(update_config, "serial", {
          class: :boolean,
          optional: true,
          default: default_update_config ? default_update_config.serial? : true,
        })

        if optional
          @canaries_before_calculation ||= default_update_config.canaries_before_calculation

          @min_canary_watch_time ||= default_update_config.min_canary_watch_time
          @max_canary_watch_time ||= default_update_config.max_canary_watch_time

          @min_update_watch_time ||= default_update_config.min_update_watch_time
          @max_update_watch_time ||= default_update_config.max_update_watch_time

          @max_in_flight_before_calculation ||= default_update_config.max_in_flight_before_calculation
        end
      end

      def to_hash
        {
          'canaries' => @canaries_before_calculation,
          'max_in_flight' => @max_in_flight_before_calculation,
          'canary_watch_time' => "#{@min_canary_watch_time}-#{@max_canary_watch_time}",
          'update_watch_time' => "#{@min_update_watch_time}-#{@max_update_watch_time}",
          'serial' => serial?,
          'strategy' => @strategy.nil? ? STRATEGY_LEGACY : @strategy,
        }
      end

      def canaries(size)
        get_numerical_value(@canaries_before_calculation, size)
      end

      def max_in_flight(size)
        value = get_numerical_value(@max_in_flight_before_calculation, size)
        (value < 1) ? 1: value
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

      def serial?
        !!@serial
      end

      private
      def get_numerical_value(value, size)
        case value
          when /^\d+%$/
            [((/\d+/.match(value)[0].to_i * size) / 100).round, size].min
          when /\A[-+]?[0-9]+\z/
            value.to_i
          else
            raise 'cannot be calculated'
        end
      end
    end
  end
end
