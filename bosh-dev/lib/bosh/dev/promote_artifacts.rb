require 'bosh/stemcell/pipeline_artifacts'

module Bosh::Dev
  class PromoteArtifacts
    def initialize(build)
      @build = build
    end

    def commands
      stemcell_artifacts = Bosh::Stemcell::PipelineArtifacts.new(build.number)

      stemcell_artifacts.list.map do |stemcell_archive_filename|
        from = File.join(source, stemcell_archive_filename.to_s)
        to = File.join(destination, stemcell_archive_filename.to_s)

        "s3cmd --verbose cp #{from} #{to}"
      end
    end

    def source
      "s3://bosh-ci-pipeline/#{build.number}/"
    end

    def destination
      's3://bosh-jenkins-artifacts'
    end

    private

    attr_reader :build
  end
end
