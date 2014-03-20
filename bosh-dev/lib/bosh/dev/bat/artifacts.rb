require 'bosh/dev'
require 'bosh/dev/build'
require 'fileutils'

module Bosh::Dev::Bat
  class Artifacts
    attr_reader :path

    def initialize(path, build, artifact_definition)
      @path = path
      @build = build
      @artifact_definition = artifact_definition
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def micro_bosh_deployment_dir
      File.join(path, micro_bosh_deployment_name)
    end

    def stemcell_path
      build.bosh_stemcell_path(artifact_definition, path)
    end

    def prepare_directories
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    private

    attr_reader :build, :artifact_definition
  end
end
