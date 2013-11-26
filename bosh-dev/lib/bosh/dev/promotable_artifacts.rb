require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/promotable_artifact'
require 'bosh/dev/gem_components'
require 'bosh/dev/gem_artifact'

module Bosh::Dev
  class PromotableArtifacts
    def initialize(build)
      @build = build
    end

    def all
      artifacts = gem_artifacts + release_artifacts + stemcell_artifacts
      artifacts << light_stemcell_pointer
    end

    def release_file
      "bosh-#{build.number}.tgz"
    end

    private

    attr_reader :build

    def light_stemcell_pointer
      LightStemcellPointer.new(build.light_stemcell)
    end

    def gem_artifacts
      gem_components = GemComponents.new(build.number)
      source = Bosh::Dev::UriProvider.pipeline_s3_path("#{build.number}", '')
      gem_components.components.map { |component| GemArtifact.new(component, source, build.number) }
    end

    def release_artifacts
      source = Bosh::Dev::UriProvider.pipeline_s3_path("#{build.number}/release", release_file)
      destination =  Bosh::Dev::UriProvider.artifacts_s3_path('release', release_file)
      commands = ["s3cmd --verbose cp #{source} #{destination}"]
      commands.map { |command| PromotableArtifact.new(command) }
    end

    def stemcell_artifacts
      stemcell_artifacts = StemcellArtifacts.all(build.number)
      commands = stemcell_artifacts.list.map do |stemcell_archive_filename|
        from = Bosh::Dev::UriProvider.pipeline_s3_path("#{build.number}", stemcell_archive_filename.to_s)
        to = Bosh::Dev::UriProvider.artifacts_s3_path('', stemcell_archive_filename.to_s)
        "s3cmd --verbose cp #{from} #{to}"
      end

      commands.map { |command| PromotableArtifact.new(command) }
    end
  end
end
