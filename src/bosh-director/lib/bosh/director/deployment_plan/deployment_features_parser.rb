module Bosh::Director::DeploymentPlan
  class DeploymentFeaturesParser

    def initialize(logger)
      @logger = logger
    end

    # @param [Hash] spec Raw features spec from the deployment manifest
    # @return [DeploymentPlan::DeploymentFeatures] DeploymentFeatures object
    def parse(spec)
      return DeploymentFeatures.new if spec.nil?

      validate(spec)

      DeploymentFeatures.new(spec['use_dns_addresses'],spec['use_short_dns_addresses'])
    end

    private

    def validate(spec)
      unless spec.is_a?(Hash)
        raise Bosh::Director::FeaturesInvalidFormat, "Key 'features' expects a Hash, but received '#{spec.class}'"
      end

      validate_use_dns_addresses(spec)
    end

    def validate_use_dns_addresses(spec)
      validate_bool_or_nil(spec, 'use_dns_addresses')
      validate_bool_or_nil(spec, 'use_short_dns_addresses')
    end

    def validate_bool_or_nil(spec, key)
      return if !spec.has_key?(key)

      if spec[key] != !!spec[key]
        raise Bosh::Director::FeaturesInvalidFormat, "Key '#{key}' in 'features' expected to be a boolean, but received '#{spec[key].class}'"
      end
    end
  end
end
