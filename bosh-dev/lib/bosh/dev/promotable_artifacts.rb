require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/promotable_artifact'

module Bosh::Dev
  class PromotableArtifacts
    def initialize(build)
      @build = build
    end

    def all
      gem_artifacts + release_artifacts + stemcell_artifacts
    end

    def source
      "s3://bosh-ci-pipeline/#{build.number}/"
    end

    def destination
      's3://bosh-jenkins-artifacts'
    end

    def release_file
      "bosh-#{build.number}.tgz"
    end

    private

    attr_reader :build

    def gem_artifacts
      commands = ["s3cmd --verbose sync #{File.join(source, 'gems/')} s3://bosh-jenkins-gems"]
      commands.map { |command| PromotableArtifact.new(command) }
    end

    def release_artifacts
      commands = ["s3cmd --verbose cp #{File.join(source, 'release', release_file)} #{File.join(destination, 'release', release_file)}"]
      commands.map { |command| PromotableArtifact.new(command) }
    end

    def stemcell_artifacts
      stemcell_artifacts = StemcellArtifacts.all(build.number)
      commands = stemcell_artifacts.list.map do |stemcell_archive_filename|
        from = File.join(source, stemcell_archive_filename.to_s)
        to = File.join(destination, stemcell_archive_filename.to_s)
        "s3cmd --verbose cp #{from} #{to}"
      end

      commands.map { |command| PromotableArtifact.new(command) }
    end
  end
end
