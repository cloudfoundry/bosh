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

      DeploymentFeatures.new(spec['use_dns_addresses'])
    end

    private

    def validate(spec)
      unless spec.is_a?(Hash)
        raise Bosh::Director::FeaturesInvalidFormat, "Key 'features' expects a Hash, but received '#{spec.class}'"
      end

      validate_use_dns_addresses(spec)
    end

    def validate_use_dns_addresses(spec)
      return if !spec.has_key?('use_dns_addresses')

      if spec['use_dns_addresses'] != !!spec['use_dns_addresses']
        raise Bosh::Director::FeaturesInvalidFormat, "Key 'use_dns_addresses' in 'features' expected to be a boolean, but received '#{spec['use_dns_addresses'].class}'"
      end
    end
  end
end
