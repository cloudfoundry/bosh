require 'bosh/dev/uri_provider'
require 'bosh/dev/command_helper'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellArtifact
    include CommandHelper

    def initialize(source_version, destination_version, stemcell_definition, logger, disk_format)
      @source_version = source_version
      @destination_version = destination_version
      @stemcell_definition = stemcell_definition
      @logger = logger
      @disk_format = disk_format
    end

    def name
      Bosh::Stemcell::ArchiveFilename.new(@destination_version, @stemcell_definition, 'bosh-stemcell', @disk_format).to_s
    end

    def promote
      stdout, stderr, status = exec_cmd("s3cmd --verbose cp #{source} #{destination}")
      raise "Failed to copy release artifact from #{source} to #{destination}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def promoted?
      return false if @destination_version == 'latest'
      _, _, status = exec_cmd("s3cmd info #{destination}")
      status.success?
    end

    private

    def source
      file_name = Bosh::Stemcell::ArchiveFilename.new(@source_version, @stemcell_definition, 'bosh-stemcell', @disk_format).to_s
      Bosh::Dev::UriProvider.pipeline_s3_path(File.join(@source_version, 'bosh-stemcell', infrastructure_name), file_name)
    end

    def destination
      Bosh::Dev::UriProvider.artifacts_s3_path(File.join('bosh-stemcell', infrastructure_name), name)
    end

    def infrastructure_name
      @stemcell_definition.infrastructure.name
    end
  end
end
