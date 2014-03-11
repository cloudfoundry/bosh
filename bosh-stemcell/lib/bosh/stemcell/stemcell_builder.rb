module Bosh::Stemcell
  class StemcellBuilder
    def initialize(dependencies = {})
      @gem_components = dependencies.fetch(:gem_components)
      @environment = dependencies.fetch(:environment)
      @collection = dependencies.fetch(:collection)
      @runner = dependencies.fetch(:runner)
    end

    def build
      gem_components.build_release_gems
      environment.prepare_build
      stemcell_stages = collection.extract_operating_system_stages +
        collection.agent_stages +
        collection.infrastructure_stages
      runner.configure_and_apply(stemcell_stages)
    end

    private

    attr_reader :gem_components, :environment, :collection, :runner
  end
end
