require 'bosh/dev/stemcell_artifacts'

module Bosh::Dev
  class PromoteArtifacts
    def initialize(build)
      @build = build
    end

    def commands
      stemcell_artifacts = StemcellArtifacts.all(build.number)

      stemcell_commands = stemcell_artifacts.list.map do |stemcell_archive_filename|
        from = File.join(source, stemcell_archive_filename.to_s)
        to = File.join(destination, stemcell_archive_filename.to_s)
        "s3cmd --verbose cp #{from} #{to}"
      end

      [
        "s3cmd --verbose sync #{File.join(source, 'gems/')} s3://bosh-jenkins-gems",
        "s3cmd --verbose cp #{File.join(source, 'release', release_file)} #{File.join(destination, 'release', release_file)}",
      ] + stemcell_commands
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
  end
end
