require 'fileutils'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  class StemcellBuilder
    def initialize(dependencies = {})
      @environment = dependencies.fetch(:environment)
      @runner = dependencies.fetch(:runner)
      @collection = dependencies.fetch(:collection)
    end

    def build
      environment.prepare_build

      stemcell_stages = collection.extract_operating_system_stages +
        collection.agent_stages +
        collection.build_stemcell_image_stages
      runner.configure_and_apply(stemcell_stages, ENV['resume_from'])
    end

    private

    attr_reader :environment, :collection, :runner
  end
end
