require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellArtifacts
    def self.all(version)
      matrix_names = [
        %w(vsphere   ubuntu),
        %w(vsphere   centos),
        %w(aws       ubuntu),
        %w(aws       centos),
        %w(openstack ubuntu),
        %w(openstack centos),
      ]

      matrix = matrix_names.map do |(infrastructure_name, os_name)|
        [
          Bosh::Stemcell::Infrastructure.for(infrastructure_name),
          Bosh::Stemcell::OperatingSystem.for(os_name),
        ]
      end

      new(version, matrix)
    end

    def initialize(version, matrix)
      @version = version
      @matrix = matrix
    end

    def list
      artifact_names = []

      matrix.each do |(infrastructure, operating_system)|
        versions.each do |version|
          filename = Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, operating_system, 'bosh-stemcell', false)
          artifact_names << archive_path(filename.to_s, infrastructure)

          if infrastructure.light?
            light_filename = Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, operating_system, 'bosh-stemcell', true)
            artifact_names << archive_path(light_filename.to_s, infrastructure)
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
