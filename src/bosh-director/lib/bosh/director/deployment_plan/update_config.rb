module Bosh::Director
  module DeploymentPlan
    class UpdateConfig
      VM_STRATEGY_CREATE_SWAP_DELETE = 'create-swap-delete'.freeze
      VM_STRATEGY_DELETE_CREATE = 'delete-create'.freeze
      ALLOWED_VM_STRATEGIES = [VM_STRATEGY_CREATE_SWAP_DELETE, VM_STRATEGY_DELETE_CREATE].freeze

      PARALLEL_AZ_UPDATE_STRATEGY = 'parallel'.freeze
      SERIAL_AZ_UPDATE_STRATEGY = 'serial'.freeze
      ALLOWED_AZ_UPDATE_STRATEGIES = [PARALLEL_AZ_UPDATE_STRATEGY, SERIAL_AZ_UPDATE_STRATEGY].freeze

      include ValidationHelper

      attr_accessor :min_canary_watch_time
      attr_accessor :max_canary_watch_time

      attr_accessor :min_update_watch_time
      attr_accessor :max_update_watch_time

      attr_reader :canaries_before_calculation
      attr_reader :max_in_flight_before_calculation

      attr_reader :vm_strategy
      attr_reader :initial_deploy_az_update_strategy

      # @param [Hash] update_config Raw instance group or deployment update config from deployment manifest
      # @param [optional, Hash] deployment_update_config Only provided when parsing instance_group level update block
      def initialize(update_config, deployment_update_config = nil)
        optional = !deployment_update_config.nil?

        @canaries_before_calculation = safe_property(update_config, 'canaries',
                                                     class: String, optional: optional)

        @max_in_flight_before_calculation = safe_property(update_config, 'max_in_flight',
                                                          class: String, optional: optional)

        canary_watch_times = safe_property(update_config, 'canary_watch_time',
                                           class: String,
                                           optional: optional)
        update_watch_times = safe_property(update_config, 'update_watch_time',
                                           class: String,
                                           optional: optional)

        if canary_watch_times
          @min_canary_watch_time, @max_canary_watch_time =
            parse_watch_times(canary_watch_times)
        end

        if update_watch_times
          @min_update_watch_time, @max_update_watch_time =
            parse_watch_times(update_watch_times)
        end

        default_vm_strategy = Config.default_update_vm_strategy || VM_STRATEGY_DELETE_CREATE
        @vm_strategy = safe_property(
          update_config,
          'vm_strategy',
          class: String,
          optional: true,
          default: deployment_update_config ? deployment_update_config.vm_strategy : default_vm_strategy,
        )

        unless @vm_strategy.nil?
          unless ALLOWED_VM_STRATEGIES.include?(@vm_strategy)
            raise ValidationInvalidValue,
                  "Invalid vm_strategy '#{vm_strategy}', valid strategies are: #{ALLOWED_VM_STRATEGIES.join(', ')}"
          end
        end

        @serial = safe_property(
          update_config,
          'serial',
          class: :boolean,
          optional: true,
          default: deployment_update_config ? deployment_update_config.serial? : true,
        )

        @initial_deploy_az_update_strategy = safe_property(
          update_config,
          'initial_deploy_az_update_strategy',
          class: String,
          optional: true,
          default: deployment_update_config ? deployment_update_config.initial_deploy_az_update_strategy : SERIAL_AZ_UPDATE_STRATEGY,
        )

        unless ALLOWED_AZ_UPDATE_STRATEGIES.include?(@initial_deploy_az_update_strategy)
          raise ValidationInvalidValue, "Invalid initial_deploy_az_update_strategy '#{@initial_deploy_az_update_strategy}', " \
                "valid strategies are: '#{ALLOWED_AZ_UPDATE_STRATEGIES.join(', ')}'"
        end

        if optional
          @canaries_before_calculation ||= deployment_update_config.canaries_before_calculation

          @min_canary_watch_time ||= deployment_update_config.min_canary_watch_time
          @max_canary_watch_time ||= deployment_update_config.max_canary_watch_time

          @min_update_watch_time ||= deployment_update_config.min_update_watch_time
          @max_update_watch_time ||= deployment_update_config.max_update_watch_time

          @max_in_flight_before_calculation ||= deployment_update_config.max_in_flight_before_calculation
        end
      end

      def to_hash
        {
          'canaries' => @canaries_before_calculation,
          'max_in_flight' => @max_in_flight_before_calculation,
          'canary_watch_time' => "#{@min_canary_watch_time}-#{@max_canary_watch_time}",
          'update_watch_time' => "#{@min_update_watch_time}-#{@max_update_watch_time}",
          'serial' => serial?,
          'vm_strategy' => @vm_strategy,
          'initial_deploy_az_update_strategy' => @initial_deploy_az_update_strategy,
        }
      end

      def canaries(size)
        NumericalValueCalculator.get_numerical_value(@canaries_before_calculation, size)
      end

      def max_in_flight(size)
        value = NumericalValueCalculator.get_numerical_value(@max_in_flight_before_calculation, size)
        value < 1 ? 1 : value
      end

      def parse_watch_times(value)
        value = value.to_s

        if value =~ /^\s*(\d+)\s*\-\s*(\d+)\s*$/
          result = [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i]
        elsif value =~ /^\s*(\d+)\s*$/
          result = [Regexp.last_match(1).to_i, Regexp.last_match(1).to_i]
        else
          raise UpdateConfigInvalidWatchTime,
                'Watch time should be an integer or a range of two integers'
        end

        if result[0] > result[1]
          raise UpdateConfigInvalidWatchTime,
                'Min watch time cannot be greater than max watch time'
        end

        result
      end

      def serial?
        !!@serial
      end

      def update_azs_in_parallel_on_initial_deploy?
        @initial_deploy_az_update_strategy == PARALLEL_AZ_UPDATE_STRATEGY
      end
    end
  end
end
