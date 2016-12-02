require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/stemcell_artifact'
require 'bosh/dev/release_artifact'
require 'bosh/dev/gem_components'
require 'bosh/dev/gem_artifact'

module Bosh::Dev
  class PromotableArtifacts
    SKIPPABLE_ARTIFACTS = ['gems', 'release', 'stemcells'].freeze

    def initialize(build, logger, opts={})
      @build = build
      @logger = logger
      @skip = opts.fetch(:skip_artifacts, [])
      @skip.each do |artifact|
        unless SKIPPABLE_ARTIFACTS.include?(artifact)
          raise "Asked to skip unknown artifact type: #{artifact}. Valid artifacts are: #{SKIPPABLE_ARTIFACTS}"
        end
      end
      @release = ReleaseArtifact.new(build.number, @logger)
    end

    def all
      artifacts = []

      artifacts << gem_artifacts if include_artifact? 'gems'
      artifacts << release_artifacts if include_artifact? 'release'
      artifacts << stemcell_artifacts if include_artifact? 'stemcells'

      artifacts.flatten
    end

    def release_file
      @release.name
    end

    private

    attr_reader :build, :skip

    def include_artifact? name
      !skip.include?(name)
    end

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
