module Bosh::Director
  module RuntimeConfig
    #TODO rename this guy
    class RuntimeInclude

      def initialize(include_spec)
        @include_spec = include_spec || {}
      end

      def find_matching_instance_group(addon_name, instance_groups, deployment_name)
        return instance_groups if @include_spec.empty?

        @addon = @include_spec[addon_name]
        instance_groups = instance_groups || []

        case {has_deployments: has_deployments?, has_jobs: has_jobs?}

          when {has_deployments: true, has_jobs: false}
            return @addon['deployments'].include?(deployment_name) ? instance_groups : []

          when {has_deployments: false, has_jobs: true}
            return filter_by_jobs(instance_groups)

          when {has_deployments: true, has_jobs: true}
            return @addon['deployments'].include?(deployment_name) ? filter_by_jobs(instance_groups) : []

          else
            return instance_groups
        end
      end

      private

      def has_deployments?
        !@addon['deployments'].empty?
      end

      def has_jobs?
        !@addon['jobs'].empty?
      end

      def filter_by_jobs(instance_groups)
        result = Set.new
        @addon['jobs'].each do |include_in_job|
          instance_groups.each do |instance_group|
            instance_group.templates.each do |job|
              if job.name == include_in_job['name'] && job.release.name == include_in_job['release']
                result << instance_group
              end
            end
          end
        end
        result.to_a
      end
    end
  end
end