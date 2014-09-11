require 'bosh/stemcell/definition'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellArtifacts
    STEMCELL_DEFINITIONS = {
      'vsphere-ubuntu-trusty' => %w(vsphere ubuntu trusty go),
      'vsphere-ubuntu-centos' => ['vsphere', 'centos', nil, 'go'],

      'aws-ubuntu-trusty' => %w(aws ubuntu trusty go),
      'aws-ubuntu-centos' => ['aws', 'centos', nil, 'go'],

      'openstack-ubuntu-trusty' => %w(openstack ubuntu trusty go),
      'openstack-ubuntu-centos' => ['openstack', 'centos', nil, 'go'],
    }

    class << self
      def all(version)
        definitions = []
        STEMCELL_DEFINITIONS.each do |key, definition_args|
          if promote_stemcell?(key)
            definitions << Bosh::Stemcell::Definition.for(*definition_args)
          end
        end

        new(version, definitions)
      end

      private

      def promote_stemcell?(key)
        return true unless ENV['BOSH_PROMOTE_STEMCELLS']
        stemcells = ENV['BOSH_PROMOTE_STEMCELLS'].split(',')
        stemcells.include?(key)
      end
    end

    def initialize(version, matrix)
      @version = version
      @matrix = matrix
    end

    def list
      artifact_names = []

      matrix.each do |definition|
        versions.each do |version|
          filename = Bosh::Stemcell::ArchiveFilename.new(version, definition, 'bosh-stemcell', false)
          artifact_names << archive_path(filename.to_s, definition.infrastructure)

          if definition.infrastructure.light?
            light_filename = Bosh::Stemcell::ArchiveFilename.new(version, definition, 'bosh-stemcell', true)
            artifact_names << archive_path(light_filename.to_s, definition.infrastructure)
          end
        end
      end

      artifact_names
    end

    private

    attr_reader :version, :matrix

    def versions
      [version, 'latest']
    end

    def archive_path(filename, infrastructure)
      File.join('bosh-stemcell', infrastructure.name, filename)
    end
  end
end
