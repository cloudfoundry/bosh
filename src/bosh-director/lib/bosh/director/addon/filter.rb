module Bosh::Director
  module Addon
    class Filter

      extend ValidationHelper

      def initialize(applicable_jobs, applicable_deployment_names, applicable_stemcells, applicable_networks, applicable_teams, filter_type)
        @applicable_jobs = applicable_jobs
        @applicable_deployment_names = applicable_deployment_names
        @applicable_stemcells = applicable_stemcells
        @applicable_networks = applicable_networks
        @applicable_teams = applicable_teams
        @filter_type = filter_type
      end

      def self.parse(addon_filter_hash, filter_type, addon_level =  RUNTIME_LEVEL)
        applicable_deployment_names = safe_property(addon_filter_hash, 'deployments', :class => Array, :default => [])
        if addon_level == DEPLOYMENT_LEVEL && !applicable_deployment_names.empty?
          raise AddonDeploymentFilterNotAllowed, 'Deployment filter is not allowed for deployment level addons.'
        end
        applicable_jobs = safe_property(addon_filter_hash, 'jobs', :class => Array, :default => [])
        applicable_stemcells = safe_property(addon_filter_hash, 'stemcell', :class => Array, :default => [])
        applicable_networks = safe_property(addon_filter_hash, 'networks', :class => Array, :default => [])
        applicable_teams = safe_property(addon_filter_hash, 'teams', :class => Array, :default => [])
        applicable_teams = [] if addon_level == DEPLOYMENT_LEVEL

        #TODO throw an exception with all wrong jobs
        verify_jobs_section(applicable_jobs, filter_type, addon_level)

        verify_stemcells_section(applicable_stemcells, filter_type, addon_level)

        new(applicable_jobs, applicable_deployment_names, applicable_stemcells, applicable_networks, applicable_teams, filter_type)
      end

      def applies?(deployment_name, deployment_teams, deployment_instance_group)
        if has_teams? && !has_applicable_team?(deployment_teams)
          return false
        end
        if has_stemcells? && !has_applicable_stemcell?(deployment_instance_group)
          return false
        end
        if has_networks? && !has_applicable_network?(deployment_instance_group)
          return false
        end
        case {has_deployments: has_deployments?, has_jobs: has_jobs?}
          when {has_deployments: true, has_jobs: false}
            return @applicable_deployment_names.include?(deployment_name)
          when {has_deployments: false, has_jobs: true}
            return has_applicable_job?(deployment_instance_group)
          when {has_deployments: true, has_jobs: true}
            return @applicable_deployment_names.include?(deployment_name) && has_applicable_job?(deployment_instance_group)
          else
            return true if @filter_type == :include
            # cases with `has_stemcells? && !has_applicable_stemcell?`, `has_networks? && !has_applicable_network?` and
            # `has_team? && !has_applicable_team?` are checked before.
            # all other cases are covered by simple check `has_stemcells? || has_networks? || has_teams?`.
            return @filter_type == :exclude && (has_stemcells? || has_networks? || has_teams?)
        end
      end

      private

      def self.verify_jobs_section(applicable_jobs, filter_type, addon_level =  RUNTIME_LEVEL)
        applicable_jobs.each do |job|
          name = safe_property(job, 'name', :class => String, :default => '')
          release = safe_property(job, 'release', :class => String, :default => '')
          if name.empty? || release.empty?
            raise AddonIncompleteFilterJobSection.new("Job #{job} in #{addon_level} config's #{filter_type} section must " +
              'have both name and release.')
          end
        end
      end

      def self.verify_stemcells_section(applicable_stemcells, filter_type, addon_level =  RUNTIME_LEVEL)
        applicable_stemcells.each do |stemcell|
          if safe_property(stemcell, 'os', :class => String, :default => '').empty?
            raise AddonIncompleteFilterStemcellSection.new("Stemcell #{stemcell} in #{addon_level} config's #{filter_type} " +
              'section must have an os name.')
          end
        end
      end

      def has_deployments?
        !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
      end

      def has_jobs?
        !@applicable_jobs.nil? && !@applicable_jobs.empty?
      end

      def has_applicable_job?(deployment_instance_group)
        @applicable_jobs.any? do |job|
          deployment_instance_group.has_job?(job['name'], job['release'])
        end
      end

      def has_stemcells?
        !@applicable_stemcells.nil? && !@applicable_stemcells.empty?
      end

      def has_applicable_stemcell?(deployment_instance_group)
        @applicable_stemcells.any? do |stemcell|
          deployment_instance_group.has_os?(stemcell['os'])
        end
      end

      def has_networks?
        !@applicable_networks.nil? && !@applicable_networks.empty?
      end

      def has_applicable_network?(deployment_instance_group)
        @applicable_networks.any? do |network_name|
          deployment_instance_group.has_network?(network_name)
        end
      end

      def has_teams?
        !@applicable_teams.nil? && !@applicable_teams.empty?
      end

      def has_applicable_team?(deployment_teams)
        return false if deployment_teams.nil? || deployment_teams.empty? || @applicable_teams.nil?
        !(@applicable_teams & deployment_teams).empty?
      end
    end
  end
end
