require 'bosh/stemcell/definition'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellArtifacts
    STEMCELL_DEFINITIONS = {
      'vsphere-esxi-ubuntu-trusty' => ['vsphere', 'esxi', 'ubuntu', 'trusty', 'go', false],
      'vsphere-esxi-centos' => ['vsphere', 'esxi', 'centos', nil, 'go', false],

      'aws-xen-ubuntu-trusty' => ['aws', 'xen', 'ubuntu', 'trusty', 'go', false],
      'aws-xen-centos' => ['aws', 'xen', 'centos', nil, 'go', false],

      'aws-xen-hvm-ubuntu-trusty' => ['aws', 'xen-hvm', 'ubuntu', 'trusty', 'go', true],
      'aws-xen-hvm-centos' => ['aws', 'xen-hvm', 'centos', nil, 'go', true],

      'openstack-kvm-ubuntu-trusty' => ['openstack', 'kvm', 'ubuntu', 'trusty', 'go', false],
      'openstack-kvm-centos' => ['openstack', 'kvm', 'centos', nil, 'go', false],
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
          filename = Bosh::Stemcell::ArchiveFilename.new(version, definition, 'bosh-stemcell')
          artifact_names << archive_path(filename.to_s, definition.infrastructure)
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
