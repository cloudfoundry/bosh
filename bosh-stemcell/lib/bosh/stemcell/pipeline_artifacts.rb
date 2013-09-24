require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'

module Bosh
  module Stemcell
    class PipelineArtifacts

      def initialize(version)
        @version = version
      end

      def list
        os = Bosh::Stemcell::OperatingSystem.for('ubuntu')

        artifact_names = []

        Bosh::Stemcell::Infrastructure.all.each do |infrastructure|
          versions.each do |version|
            filename = Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, os, 'bosh-stemcell', false)
            artifact_names << archive_path(filename.to_s, infrastructure)

            if infrastructure.light?
              light_filename = Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, os, 'bosh-stemcell', true)
              artifact_names << archive_path(light_filename.to_s, infrastructure)
            end
          end
        end

        artifact_names
      end

      private

      def versions
        [version, 'latest']
      end

      def archive_path(filename, infrastructure)
        File.join('bosh-stemcell', infrastructure.name, filename)
      end

      attr_reader :version
    end
  end
end
