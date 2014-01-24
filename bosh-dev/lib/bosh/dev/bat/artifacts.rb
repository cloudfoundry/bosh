require 'bosh/dev'
require 'bosh/dev/build'
require 'fileutils'

module Bosh::Dev::Bat
  class Artifacts
    attr_reader :path

    def initialize(path, build, microbosh_definition, bat_definition)
      @path = path
      @build = build
      @microbosh_definition = microbosh_definition
      @bat_definition = bat_definition
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def micro_bosh_deployment_dir
      File.join(path, micro_bosh_deployment_name)
    end

    def bosh_stemcell_path
      build.bosh_stemcell_path(microbosh_definition, path)
    end

    def bat_stemcell_path
      build.bosh_stemcell_path(bat_definition, path)
    end

    def prepare_directories
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    private

    attr_reader :build, :microbosh_definition, :bat_definition
  end
end
