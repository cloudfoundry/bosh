module Bosh::Director
  module DeploymentPlan
    class DeploymentFeatures
      attr_reader :converge_variables
      attr_reader :randomize_az_placement
      attr_reader :use_dns_addresses
      attr_reader :use_link_dns_names
      attr_reader :use_short_dns_addresses
      attr_reader :use_tmpfs_job_config

      def initialize(
        use_dns_addresses = nil,
        use_short_dns_addresses = nil,
        randomize_az_placement = nil,
        converge_variables = false,
        use_link_dns_names = false,
        use_tmpfs_job_config = false
      )
        @use_dns_addresses = use_dns_addresses
        @use_link_dns_names = use_link_dns_names
        @use_short_dns_addresses = use_short_dns_addresses
        @randomize_az_placement = randomize_az_placement
        @converge_variables = converge_variables
        @use_tmpfs_job_config = use_tmpfs_job_config
      end
    end
  end
end
