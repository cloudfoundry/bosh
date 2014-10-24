require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/stemcell_artifact'
require 'bosh/dev/release_artifact'
require 'bosh/dev/gem_components'
require 'bosh/dev/gem_artifact'

module Bosh::Dev
  class PromotableArtifacts
    def initialize(build, logger)
      @build = build
      @logger = logger
      @release = ReleaseArtifact.new(build.number, @logger)
    end

    def all
      gem_artifacts + release_artifacts + stemcell_artifacts
    end

    def release_file
      @release.name
    end

    private

    attr_reader :build

    def gem_artifacts
      gem_components = GemComponents.new(build.number)
      source = Bosh::Dev::UriProvider.pipeline_s3_path("#{build.number}", '')
      gem_components.components.map { |component| GemArtifact.new(component, source, build.number, @logger) }
    end

    def release_artifacts
      [ @release ]
    end

    def stemcell_artifacts
      StemcellArtifacts.all(build.number, @logger).list
    end
  end
end
