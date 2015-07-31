module Bosh::Director
  module DeploymentPlan
    class JobAvilabilityZoneParser
      include ValidationHelper

      def parse(job_spec, job, deployment, networks)
        az_names = safe_property(job_spec, 'availability_zones', class: Array, optional: true)
        return nil if az_names.nil?

        check_validity_of(az_names, job, deployment)
        check_contains(az_names, networks, job)
        az_names
      end

      def check_contains(az_names, networks, job)
        networks.each do |network|
          network.validate_has_job!(az_names, job.name)
        end
      end

      def check_validity_of(az_names, job, deployment)
        if az_names.empty?
          raise JobMissingAvailabilityZones, "Job `fake-job-name' has empty availability zones"
        end

        az_names.each do |name|
          unless name.is_a?(String)
            raise JobInvalidAvailabilityZone, "Job `#{job.name}' has invalid availability zone '#{name}', string expected"
          end

          if deployment.availability_zone(name).nil?
            raise JobUnknownAvailabilityZone, "Job `#{job.name}' references unknown availability zone '#{name}'"
          end
        end
      end
    end
  end
end


