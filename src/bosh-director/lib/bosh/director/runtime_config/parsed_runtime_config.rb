module Bosh::Director
  module RuntimeConfig
    class ParsedRuntimeConfig
      attr_reader :releases, :addons, :variables

      def initialize(releases, addons, variables)
        @releases = releases
        @addons = addons
        @variables = variables
      end

      def get_applicable_addons(deployment_plan)
        @addons.select do |addon|
          deployment_plan.instance_groups.any? do |instance_group|
            addon.applies?(deployment_plan.name, deployment_plan.team_names, instance_group)
          end
        end
      end

      def get_applicable_releases(deployment_plan)
        get_applicable_addons(deployment_plan).flat_map do |addon|
          addon.releases.flat_map do |release_name|
            @releases.select do |release|
              release.name == release_name
            end
          end
        end.uniq
      end
    end
  end
end
