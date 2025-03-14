require 'bosh/common/template/property_helper'

module Bosh::Director::DeploymentPlan
  class VariablesSpecParser

    def initialize(logger, deployment_model)
      @logger = logger
      @deployment_model = deployment_model
    end

    # @param [Array] spec Raw variables spec from the deployment manifest
    # @return [DeploymentPlan::Variables] Variables object
    def parse(spec)
      validate(spec) if spec
      parse_links(spec)
      Variables.new(spec)
    end

    private

    def parse_links(spec)
      return if spec.nil?
      parser = Bosh::Director::Links::LinksParser.new
      spec.each do |variable|
        parser.parse_consumers_from_variable(variable, @deployment_model)
      end
    end

    def validate(spec)
      unless spec.is_a?(Array)
        raise Bosh::Director::VariablesInvalidFormat,
              "Key 'variables' expects an array, but received '#{spec.class}'"
      end

      validate_elements_are_hashes(spec)
      validate_mandatory_fields(spec)
      validate_consumes_field(spec)
      validate_duplicate_names(spec)
      validate_options(spec)
      validate_update_mode(spec)
    end

    def validate_elements_are_hashes(spec)
      spec.each do |variable|
        unless variable.is_a?(Hash)
          raise Bosh::Director::VariablesInvalidFormat, "All 'variables' elements should be Hashes"
        end
      end
    end

    def validate_mandatory_fields(spec)
      spec.each do |variable|
        if !variable.has_key?('name')
          raise Bosh::Director::VariablesInvalidFormat,
                "At least one of the variables is missing the 'name' key; 'name' must be specified"
        end

        if !variable['name'] || variable['name'].strip.empty?
          raise Bosh::Director::VariablesInvalidFormat,
                "At least one of the variables has an empty 'name'; 'name' must not be empty or nil"
        end

        if !variable.has_key?('type')
          raise Bosh::Director::VariablesInvalidFormat,
                "Type for variable '#{variable['name']}' is missing; 'type' must be specified"
        end

        if variable['type'].nil?
          raise Bosh::Director::VariablesInvalidFormat,
                "Type for variable '#{variable['name']}' is nil; 'type' must not be nil"
        end

        if !variable['type'].is_a?(String)
          raise Bosh::Director::VariablesInvalidFormat,
                "Type for variable '#{variable['name']}' must be a String, but was '#{variable['type']}'"
        end

        if variable['type'].strip.empty?
          raise Bosh::Director::VariablesInvalidFormat,
                "Type for variable '#{variable['name']}' is empty; 'type' must not be empty"
        end
      end
    end

    def validate_consumes_field(spec)
      spec.each do |variable|
        if !variable['consumes'].nil? && !variable['consumes'].is_a?(Hash)
          raise Bosh::Director::VariablesInvalidFormat,
                "Consumes for variable '#{variable['name']}' must be a Hash or nil"
        end
      end
    end

    def validate_duplicate_names(spec)
      duplicate_name = spec.detect do |variable|
        spec.count{ |v| v['name'] == variable['name']} > 1
      end
      if duplicate_name
        raise Bosh::Director::VariablesInvalidFormat,
              "Some of the variables have duplicate names, eg: '#{duplicate_name['name']}'"
      end
    end

    def validate_options(spec)
      spec.each do |variable|
        options = variable['options']

        if options && !options.is_a?(Hash)
          raise Bosh::Director::VariablesInvalidFormat, "options of variable with name '#{variable['name']}' is not a Hash"
        end
      end
    end

    def validate_update_mode(spec)
      spec.each do |variable|
        if !variable['update_mode'].nil? && !variable['update_mode'].is_a?(String)
          raise Bosh::Director::VariablesInvalidFormat,
                "Update mode for variable '#{variable['name']}' must be a String, but was '#{variable['update_mode']}'"
        end
      end
    end
  end
end
