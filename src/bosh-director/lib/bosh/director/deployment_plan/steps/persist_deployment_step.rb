module Bosh::Director
  module DeploymentPlan
    module Steps
      class PersistDeploymentStep

        def initialize(deployment_plan)
          @deployment_plan = deployment_plan
        end

        def perform
          #prior updates may have had release versions that we no longer use.
          #remove the references to these stale releases.
          stale_release_versions = (@deployment_plan.model.release_versions - @deployment_plan.releases.map(&:model))
          # stale_release_names = stale_release_versions.map {|version_model| version_model.release.name}.uniq
          # @deployment_plan.with_release_locks(stale_release_names) do
            stale_release_versions.each do |release_version|
              @deployment_plan.model.remove_release_version(release_version)
            end
          # end

          @deployment_plan.model.manifest = YAML.dump(@deployment_plan.uninterpolated_manifest_hash)
          @deployment_plan.model.manifest_text = @deployment_plan.raw_manifest_text
          @deployment_plan.model.cloud_configs = @deployment_plan.cloud_configs
          @deployment_plan.model.runtime_configs = @deployment_plan.runtime_configs
          @deployment_plan.model.link_spec = @deployment_plan.link_spec
          @deployment_plan.model.save
        end
      end
    end
  end
end
