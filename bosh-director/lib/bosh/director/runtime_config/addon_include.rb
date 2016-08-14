module Bosh::Director
  module RuntimeConfig
    class AddonInclude

      extend ValidationHelper

      def initialize(applicable_jobs, applicable_deployment_names, applicable_stemcells)
        @applicable_jobs = applicable_jobs
        @applicable_deployment_names = applicable_deployment_names
        @applicable_stemcells = applicable_stemcells
      end

      def self.parse(addon_include_hash)
        applicable_deployment_names = safe_property(addon_include_hash, 'deployments', :class => Array, :default => [])
        applicable_jobs = safe_property(addon_include_hash, 'jobs', :class => Array, :default => [])
        applicable_stemcells = safe_property(addon_include_hash, 'stemcell', :class => Array, :default => [])

        #TODO throw an exception with all wrong jobs
        verify_jobs_section(applicable_jobs)

        verify_stemcells_section(applicable_stemcells)

        new(applicable_jobs, applicable_deployment_names, applicable_stemcells)
      end

      def applies?(deployment_name, deployment_instance_group)
        if has_stemcells? && !has_applicable_stemcell(deployment_instance_group)
          return false
        end
        case {has_deployments: has_deployments?, has_jobs: has_jobs?}
          when {has_deployments: true, has_jobs: false}
            return @applicable_deployment_names.include?(deployment_name)
          when {has_deployments: false, has_jobs: true}
            return has_applicable_job(deployment_instance_group)
          when {has_deployments: true, has_jobs: true}
            return @applicable_deployment_names.include?(deployment_name) && has_applicable_job(deployment_instance_group)
          else
            return true
        end
      end

      private

      def self.verify_jobs_section(applicable_jobs)
        applicable_jobs.each do |job|
          name = safe_property(job, 'name', :class => String, :default => '')
          release = safe_property(job, 'release', :class => String, :default => '')
          if name.empty? || release.empty?
            raise RuntimeIncompleteIncludeJobSection.new("Job #{job} in runtime config's include section must " +
              'have both name and release.')
          end
        end
      end

      def self.verify_stemcells_section(applicable_stemcells)
        applicable_stemcells.each do |stemcell|
          if safe_property(stemcell, 'os', :class => String, :default => '').empty?
            raise RuntimeIncompleteIncludeStemcellSection.new("Stemcell #{stemcell} in runtime config's " +
              'include section must have an os name.')
          end
        end
      end

      def has_deployments?
        !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
      end

      def has_jobs?
        !@applicable_jobs.nil? && !@applicable_jobs.empty?
      end

      def has_applicable_job(deployment_instance_group)
        @applicable_jobs.any? do |job|
          deployment_instance_group.has_job?(job['name'], job['release'])
        end
      end

      def has_stemcells?
        !@applicable_stemcells.nil? && !@applicable_stemcells.empty?
      end

      def has_applicable_stemcell(deployment_instance_group)
        @applicable_stemcells.any? do |stemcell|
          deployment_instance_group.has_os?(stemcell['os'])
        end
      end

    end
  end
end
