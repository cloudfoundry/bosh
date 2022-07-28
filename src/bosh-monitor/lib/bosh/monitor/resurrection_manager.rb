module Bosh::Monitor
  class ResurrectionManager
    def initialize
      @parsed_rules = []
      @logger = Bhm.logger
      @resurrection_config_sha = []
    end

    def resurrection_enabled?(deployment_name, instance_group)
      enabled = true
      @parsed_rules.each do |parsed_rule|
        enabled &&= parsed_rule.enabled? if parsed_rule.applies?(deployment_name, instance_group)
      end

      enabled
    end

    def update_rules(resurrection_configs)
      return if resurrection_configs.nil?

      new_parsed_rules = []

      resurrection_config_sha = resurrection_configs.map do |resurrection_config|
        Digest::SHA256.digest(resurrection_config['content'])
      end

      if @resurrection_config_sha.to_set != resurrection_config_sha.to_set
        @logger.info('Resurrection config update starting...')

        resurrection_rule_hashes = resurrection_configs.map do |resurrection_config|
          YAML.safe_load(resurrection_config['content'])['rules']
        end.flatten || []

        resurrection_rule_hashes.each do |resurrection_rule_hash|
          new_parsed_rules << ResurrectionRule.parse(resurrection_rule_hash)
        rescue StandardError => e
          @logger.error("Failed to parse resurrection config rule #{resurrection_rule_hash.inspect}: #{e.inspect}")
        end

        @parsed_rules = new_parsed_rules
        @resurrection_config_sha = resurrection_config_sha
        @logger.info('Resurrection config update finished')
      else
        @logger.info('Resurrection config remains the same')
      end
    end

    class ResurrectionRule
      def initialize(enabled, include_filter, exclude_filter)
        @enabled = enabled
        @include_filter = include_filter
        @exclude_filter = exclude_filter
      end

      def self.parse(resurrection_rule_hash)
        if !resurrection_rule_hash.is_a?(Hash) || !resurrection_rule_hash.key?('enabled')
          raise ConfigProcessingError, "Required property 'enabled' was not specified in object"
        end

        enabled = resurrection_rule_hash.fetch('enabled')

        unless enabled.is_a?(TrueClass) || enabled.is_a?(FalseClass)
          raise ConfigProcessingError, "Property 'enabled' value (#{enabled.inspect}) did not match the required type 'Boolean'"
        end

        include_filter = Filter.parse(resurrection_rule_hash.fetch('include', {}), :include)
        exclude_filter = Filter.parse(resurrection_rule_hash.fetch('exclude', {}), :exclude)
        new(enabled, include_filter, exclude_filter)
      end

      def enabled?
        @enabled
      end

      def applies?(deployment_name, instance_group)
        @include_filter.applies?(deployment_name, instance_group) && !@exclude_filter.applies?(deployment_name, instance_group)
      end
    end

    class Filter
      def initialize(applicable_deployment_names, applicable_instance_groups, filter_type)
        @applicable_deployment_names = applicable_deployment_names
        @applicable_instance_groups = applicable_instance_groups
        @filter_type = filter_type
      end

      def self.parse(filter_hash, filter_type)
        applicable_deployment_names = filter_hash.fetch('deployments', [])
        applicable_instance_groups = filter_hash.fetch('instance_groups', [])
        new(applicable_deployment_names, applicable_instance_groups, filter_type)
      end

      def applies?(deployment_name, instance_group)
        return false if instance_groups? && !@applicable_instance_groups.include?(instance_group)

        return false if deployments? && !@applicable_deployment_names.include?(deployment_name)

        return true if @filter_type == :include

        any_filter?
      end

      def deployments?
        !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
      end

      def instance_groups?
        !@applicable_instance_groups.nil? && !@applicable_instance_groups.empty?
      end

      def any_filter?
        (deployments? || instance_groups?)
      end
    end
  end
end
