module Bosh::Director
  module Addon
    class Filter
      extend ValidationHelper

      def initialize(jobs:,
                     instance_groups:,
                     deployment_names:,
                     stemcells:,
                     networks:,
                     teams:,
                     availability_zones:,
                     lifecycle_type:,
                     filter_type:)
        @applicable_jobs = jobs
        @applicable_instance_groups = instance_groups
        @applicable_deployment_names = deployment_names
        @applicable_stemcells = stemcells
        @applicable_networks = networks
        @applicable_teams = teams
        @applicable_availability_zones = availability_zones
        @applicable_lifecycle_type = lifecycle_type
        @filter_type = filter_type
      end

      def self.parse(addon_filter_hash, filter_type, addon_level = RUNTIME_LEVEL)
        applicable_deployment_names = safe_property(addon_filter_hash, 'deployments', class: Array, default: [])
        if addon_level == DEPLOYMENT_LEVEL && !applicable_deployment_names.empty?
          raise AddonDeploymentFilterNotAllowed, 'Deployment filter is not allowed for deployment level addons.'
        end
        applicable_jobs = safe_property(addon_filter_hash, 'jobs', class: Array, default: [])
        applicable_instance_groups = safe_property(addon_filter_hash, 'instance_groups', class: Array, default: [])
        applicable_stemcells = safe_property(addon_filter_hash, 'stemcell', class: Array, default: [])
        applicable_networks = safe_property(addon_filter_hash, 'networks', class: Array, default: [])
        applicable_teams = safe_property(addon_filter_hash, 'teams', class: Array, default: [])
        applicable_teams = [] if addon_level == DEPLOYMENT_LEVEL
        applicable_availability_zones = safe_property(addon_filter_hash, 'azs', class: Array, default: [])
        applicable_lifecycle_type = safe_property(addon_filter_hash, 'lifecycle', class: String, default: '')

        # TODO: throw an exception with all wrong jobs
        verify_jobs_section(applicable_jobs, filter_type, addon_level)

        verify_stemcells_section(applicable_stemcells, filter_type, addon_level)

        new(
          jobs: applicable_jobs,
          instance_groups: applicable_instance_groups,
          deployment_names: applicable_deployment_names,
          stemcells: applicable_stemcells,
          networks: applicable_networks,
          teams: applicable_teams,
          availability_zones: applicable_availability_zones,
          lifecycle_type: applicable_lifecycle_type,
          filter_type: filter_type,
        )
      end

      def applies?(deployment_name, deployment_teams, deployment_instance_group)
        return false if lifecycle? && !applicable_lifecycle?(deployment_instance_group)
        return false if availability_zones? && !applicable_availability_zones?(deployment_instance_group)
        return false if teams? && !applicable_team?(deployment_teams)
        return false if stemcells? && !applicable_stemcell?(deployment_instance_group)
        return false if networks? && !applicable_network?(deployment_instance_group)
        deployments_jobs_and_instance_groups = {
          has_deployments: deployments?,
          has_jobs: jobs?,
          has_instance_groups: instance_groups?,
        }
        case deployments_jobs_and_instance_groups
        when { has_deployments: true, has_instance_groups: true, has_jobs: true }
          return @applicable_deployment_names.include?(deployment_name) &&
                 applicable_job?(deployment_instance_group) &&
                 applicable_instance_group?(deployment_instance_group)
        when { has_deployments: true, has_instance_groups: false, has_jobs: true }
          return @applicable_deployment_names.include?(deployment_name) &&
                 applicable_job?(deployment_instance_group)
        when { has_deployments: true, has_instance_groups: true, has_jobs: false }
          return @applicable_deployment_names.include?(deployment_name) &&
                 applicable_instance_group?(deployment_instance_group)
        when { has_deployments: true, has_instance_groups: false, has_jobs: false }
          return @applicable_deployment_names.include?(deployment_name)
        when { has_deployments: false, has_instance_groups: true, has_jobs: true }
          return applicable_job?(deployment_instance_group) &&
                 applicable_instance_group?(deployment_instance_group)
        when { has_deployments: false, has_instance_groups: false, has_jobs: true }
          return applicable_job?(deployment_instance_group)
        when { has_deployments: false, has_instance_groups: true, has_jobs: false }
          return applicable_instance_group?(deployment_instance_group)
        when { has_deployments: false, has_instance_groups: false, has_jobs: false }
          return true if @filter_type == :include
          # cases with `has_stemcells? && !has_applicable_stemcell?`, `has_networks? && !has_applicable_network?`,
          # `has_team? && !has_applicable_team?`, has_availability_zones? && !has_applicable_availability_zones?
          # are checked before. all other cases are covered by simple check
          # `has_stemcells? || has_networks? || has_teams?` || has_availability_zones?
          return @filter_type == :exclude && (stemcells? || networks? || teams? || availability_zones? || lifecycle?)
        end
      end

      private_class_method

      def self.verify_jobs_section(applicable_jobs, filter_type, addon_level = RUNTIME_LEVEL)
        applicable_jobs.each do |job|
          name = safe_property(job, 'name', class: String, default: '')
          release = safe_property(job, 'release', class: String, default: '')
          if name.empty? || release.empty?
            raise AddonIncompleteFilterJobSection, "Job #{job} in #{addon_level} config's #{filter_type} section must " \
              'have both name and release.'
          end
        end
      end

      def self.verify_stemcells_section(applicable_stemcells, filter_type, addon_level = RUNTIME_LEVEL)
        applicable_stemcells.each do |stemcell|
          if safe_property(stemcell, 'os', class: String, default: '').empty?
            raise AddonIncompleteFilterStemcellSection, "Stemcell #{stemcell} in #{addon_level} config's #{filter_type} " \
              'section must have an os name.'
          end
        end
      end

      def deployments?
        !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
      end

      def instance_groups?
        !@applicable_instance_groups.nil? && !@applicable_instance_groups.empty?
      end

      def jobs?
        !@applicable_jobs.nil? && !@applicable_jobs.empty?
      end

      def applicable_instance_group?(deployment_instance_group)
        @applicable_instance_groups.include?(deployment_instance_group.name)
      end

      def applicable_job?(deployment_instance_group)
        @applicable_jobs.any? do |job|
          deployment_instance_group.has_job?(job['name'], job['release'])
        end
      end

      def stemcells?
        !@applicable_stemcells.nil? && !@applicable_stemcells.empty?
      end

      def applicable_stemcell?(deployment_instance_group)
        @applicable_stemcells.any? do |stemcell|
          deployment_instance_group.has_os?(stemcell['os'])
        end
      end

      def networks?
        !@applicable_networks.nil? && !@applicable_networks.empty?
      end

      def applicable_network?(deployment_instance_group)
        @applicable_networks.any? do |network_name|
          deployment_instance_group.network_present?(network_name)
        end
      end

      def teams?
        !@applicable_teams.nil? && !@applicable_teams.empty?
      end

      def applicable_team?(deployment_teams)
        return false if deployment_teams.nil? || deployment_teams.empty? || @applicable_teams.nil?
        !(@applicable_teams & deployment_teams).empty?
      end

      def availability_zones?
        !@applicable_availability_zones.nil? && !@applicable_availability_zones.empty?
      end

      def applicable_availability_zones?(deployment_instance_group)
        @applicable_availability_zones.any? do |az_name|
          deployment_instance_group.has_availability_zone?(az_name)
        end
      end

      def lifecycle?
        !@applicable_lifecycle_type.empty? && !@applicable_lifecycle_type.nil?
      end

      def applicable_lifecycle?(deployment_instance_group)
        @applicable_lifecycle_type == deployment_instance_group.lifecycle
      end
    end
  end
end
