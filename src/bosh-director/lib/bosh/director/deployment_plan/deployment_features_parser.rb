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
      use_dns_addresses = spec.fetch('use_dns_addresses', spec['use_link_dns_names'])
      use_short_dns_addresses = spec.fetch('use_short_dns_addresses', spec['use_link_dns_names'])

      DeploymentFeatures.new(
        use_dns_addresses,
        use_short_dns_addresses,
        spec['randomize_az_placement'],
        spec.fetch('converge_variables', false),
        spec['use_link_dns_names'],
        spec.fetch('use_tmpfs_job_config', false),
      )
    end

    private

    def validate(spec)
      unless spec.is_a?(Hash)
        raise Bosh::Director::FeaturesInvalidFormat, "Key 'features' expects a Hash, but received '#{spec.class}'"
      end

      validate_use_dns_addresses(spec)
      validate_bool_or_nil(spec, 'converge_variables')
      validate_bool_or_nil(spec, 'use_tmpfs_job_config')
      validate_dns_consistency(spec)
    end

    def validate_use_dns_addresses(spec)
      validate_bool_or_nil(spec, 'use_dns_addresses')
      validate_bool_or_nil(spec, 'use_link_dns_names')
      validate_bool_or_nil(spec, 'use_short_dns_addresses')
      validate_bool_or_nil(spec, 'randomize_az_placement')
    end

    def validate_dns_consistency(spec)
      return unless spec['use_link_dns_names']

      enforce_unset_or_true!(spec, 'use_short_dns_addresses')
      enforce_unset_or_true!(spec, 'use_dns_addresses')
    end

    def enforce_unset_or_true!(spec, key)
      return unless spec.key?(key) && !spec[key]

      raise(
        Bosh::Director::IncompatibleFeatures,
        "cannot enable `use_link_dns_names` when `#{key}` is explicitly disabled",
      )
    end

    def validate_bool_or_nil(spec, key)
      return unless spec.key?(key)

      if spec[key] != !!spec[key]
        raise Bosh::Director::FeaturesInvalidFormat, "Key '#{key}' in 'features' expected to be a boolean, but received '#{spec[key].class}'"
      end
    end
  end
end
