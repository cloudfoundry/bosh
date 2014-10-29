require 'bosh/dev/uri_provider'
require 'bosh/dev/command_helper'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellArtifact
    include CommandHelper

    def initialize(version, stemcell_definition, logger)
      @version = version
      @stemcell_definition = stemcell_definition
      @logger = logger
    end

    def name
      filename = Bosh::Stemcell::ArchiveFilename.new(@version, @stemcell_definition, 'bosh-stemcell')
      "#{filename}.tgz"
    end

    def promote
      stdout, stderr, status = exec_cmd("s3cmd --verbose cp #{source} #{destination}")
      raise "Failed to copy release artifact from #{source} to #{destination}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
    end

    def promoted?
      _, _, status = exec_cmd("s3cmd info #{destination}")
      status.success?
    end

    private

    def source
      Bosh::Dev::UriProvider.pipeline_s3_path(File.join(@version, 'bosh-stemcell', infrastructure_name), name)
    end

    def destination
      Bosh::Dev::UriProvider.artifacts_s3_path(File.join('bosh-stemcell', infrastructure_name), name)
    end

    def infrastructure_name
      @stemcell_definition.infrastructure.name
    end
  end
end
