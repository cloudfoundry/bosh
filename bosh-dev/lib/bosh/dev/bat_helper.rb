require 'bosh/dev/infrastructure'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class BatHelper
    attr_reader :infrastructure

    def initialize(infrastructure)
      @infrastructure = Infrastructure.for(infrastructure)
      @pipeline = Pipeline.new
    end

    def bosh_stemcell_path
      pipeline.bosh_stemcell_path(infrastructure, artifacts_dir)
    end

    def micro_bosh_stemcell_path
      pipeline.micro_bosh_stemcell_path(infrastructure, artifacts_dir)
    end

    def artifacts_dir
      File.join('/tmp', 'ci-artifacts', infrastructure.name, 'deployments')
    end

    def micro_bosh_deployment_dir
      File.join(artifacts_dir, micro_bosh_deployment_name)
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def run_rake
      infrastructure_for_emitable_example

      sanitize_directories

      prepare_directories

      sanitize_directories

      prepare_directories

      pipeline.fetch_stemcells(infrastructure, artifacts_dir)

      infrastructure.run_system_micro_tests
    end

    private

    attr_reader :pipeline

    def infrastructure_for_emitable_example
      ENV['BAT_INFRASTRUCTURE'] = infrastructure.name
    end

    def sanitize_directories
      FileUtils.rm_rf(artifacts_dir)
    end

    def prepare_directories
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end
  end
end
