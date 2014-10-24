require 'bosh/stemcell/definition'
require 'bosh/stemcell/archive_filename'
require 'bosh/dev/stemcell_artifact'

module Bosh::Dev
  class StemcellArtifacts
    STEMCELL_DEFINITIONS = {
      'vsphere-esxi-ubuntu-trusty' => ['vsphere', 'esxi', 'ubuntu', 'trusty', 'go', false],
      'vsphere-esxi-centos' => ['vsphere', 'esxi', 'centos', nil, 'go', false],

      'vcloud-esxi-ubuntu-trusty' => ['vcloud', 'esxi', 'ubuntu', 'trusty', 'go', false],

      'light-aws-xen-ubuntu-trusty' => ['aws', 'xen', 'ubuntu', 'trusty', 'go', true],
      'aws-xen-ubuntu-trusty' => ['aws', 'xen', 'ubuntu', 'trusty', 'go', false],

      'light-aws-xen-centos' => ['aws', 'xen', 'centos', nil, 'go', true],
      'aws-xen-centos' => ['aws', 'xen', 'centos', nil, 'go', false],

      'light-aws-xen-hvm-ubuntu-trusty' => ['aws', 'xen-hvm', 'ubuntu', 'trusty', 'go', true],
      'light-aws-xen-hvm-centos' => ['aws', 'xen-hvm', 'centos', nil, 'go', true],

      'openstack-kvm-ubuntu-trusty' => ['openstack', 'kvm', 'ubuntu', 'trusty', 'go', false],
      'openstack-kvm-centos' => ['openstack', 'kvm', 'centos', nil, 'go', false],
    }

    class << self
      def all(version, logger)
        definitions = []
        STEMCELL_DEFINITIONS.each do |key, definition_args|
          if promote_stemcell?(key)
            definitions << Bosh::Stemcell::Definition.for(*definition_args)
          end
        end

        new(version, definitions, logger)
      end

      private

      def promote_stemcell?(key)
        return true unless ENV['BOSH_PROMOTE_STEMCELLS']
        stemcells = ENV['BOSH_PROMOTE_STEMCELLS'].split(',')
        stemcells.include?(key)
      end
    end

    def initialize(version, matrix, logger)
      @version = version
      @matrix = matrix
      @logger = logger
    end

    def list
      artifacts = []

      @matrix.each do |stemcell_definition|
        artifacts << StemcellArtifact.new(@version, stemcell_definition, @logger)
        artifacts << StemcellArtifact.new('latest', stemcell_definition, @logger)
      end

      artifacts
    end
  end
end
