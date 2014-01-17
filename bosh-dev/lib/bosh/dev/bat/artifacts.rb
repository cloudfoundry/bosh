require 'bosh/dev'
require 'bosh/dev/build'
require 'fileutils'

module Bosh::Dev::Bat
  class Artifacts
    attr_reader :path

    def initialize(path, build, stemcell_definition)
      @path = path
      @build = build
      @stemcell_definition = stemcell_definition
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def micro_bosh_deployment_dir
      File.join(path, micro_bosh_deployment_name)
    end

    def bosh_stemcell_path
      build.bosh_stemcell_path(stemcell_definition, path)
    end

    def prepare_directories
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    private

    attr_reader :build, :stemcell_definition
  end
end
