require 'bosh/dev'
require 'bosh/dev/build'
require 'fileutils'
require 'bosh/stemcell/stemcell'

module Bosh::Dev::Bat
  class Artifacts
    attr_reader :path

    def initialize(path, stemcell)
      @path = path
      @stemcell = stemcell
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def micro_bosh_deployment_dir
      File.join(path, micro_bosh_deployment_name)
    end

    def stemcell_path
      File.join(path, stemcell.name)
    end

    def prepare_directories
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    private

    attr_reader :stemcell
  end
end
