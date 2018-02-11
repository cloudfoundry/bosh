module Bosh::Monitor
  class ResurrectionManager
    def initialize()
      @parsed_rules = []
      @logger = Bhm.logger
      @active_ids = []
    end

    def resurrection_enabled?(deployment_name, instance_group)
      enabled = true
      @parsed_rules.each do |parsed_rule|
        enabled = enabled && parsed_rule.enabled? if parsed_rule.applies?(deployment_name, instance_group)
      end

      return enabled
    end

    def update_rules(resurrection_configs)
      new_parsed_rules = []
      if !resurrection_configs.nil? && !resurrection_configs.empty?
        ids = resurrection_configs.map{ |resurrection_config| resurrection_config['id'] }
        if @active_ids.to_set != ids.to_set
          @logger.info("Resurrection config update starting...")

          resurrection_rule_hashes = resurrection_configs.map{ |resurrection_config| YAML.load(resurrection_config['content'])['rules'] }.flatten || []
          resurrection_rule_hashes.each do |resurrection_rule_hash|
            begin
              new_parsed_rules << ResurrectionRule.parse(resurrection_rule_hash)
            rescue Exception => e
              @logger.error("Failed to parse resurrection config rule #{resurrection_rule_hash.inspect}: #{e.inspect}")
            end
          end
          @parsed_rules = new_parsed_rules
          @active_ids = ids
          @logger.info("Resurrection config update finished")
        else
          @logger.info("Resurrection config remains the same")
        end
      end
    end

    private

    class ResurrectionRule
      def initialize(options, include_filter, exclude_filter)
        @options = options
        @include_filter = include_filter
        @exclude_filter = exclude_filter
      end

      def self.parse(resurrection_rule_hash)
        if !resurrection_rule_hash.kind_of?(Hash) || !resurrection_rule_hash.key?('options')
          raise ConfigProcessingError, "Invalid format for resurrection config: expected 'options' to be presented"
        end
        options = resurrection_rule_hash.fetch('options')
        if !options.kind_of?(Hash) || !options.key?('enabled')
          raise ConfigProcessingError, "Invalid format for resurrection config: expected 'enabled' option, got #{options.class}: #{options}"
        end
        include_filter = Filter.parse(resurrection_rule_hash.fetch('include', {}), :include)
        exclude_filter = Filter.parse(resurrection_rule_hash.fetch('exclude', {}), :exclude)
        new(options, include_filter, exclude_filter)
      end

      def enabled?
        !!@options['enabled']
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
        applicable_deployment_names =  filter_hash.fetch('deployments', [])
        applicable_instance_groups = filter_hash.fetch('instance_groups', [])
        new(applicable_deployment_names, applicable_instance_groups, filter_type)
      end

      def applies?(deployment_name, instance_group)
        if has_instance_groups? && !@applicable_instance_groups.include?(instance_group)
          return false
        end

        if has_deployments? &&  !@applicable_deployment_names.include?(deployment_name)
          return false
        end

        return true if @filter_type == :include
        return @filter_type == :exclude && (has_deployments? || has_instance_groups?)
      end

      def has_deployments?
        !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
      end

      def has_instance_groups?
        !@applicable_instance_groups.nil? && !@applicable_instance_groups.empty?
      end
    end
  end
end