require 'bosh/dev/infrastructure'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class BatHelper
    attr_reader :infrastructure

    def initialize(infrastructure)
      @infrastructure = Infrastructure.new(infrastructure)
      @pipeline = Pipeline.new
    end

    def bosh_stemcell_path
      pipeline.bosh_stemcell_path(infrastructure)
    end

    def micro_bosh_stemcell_path
      pipeline.micro_bosh_stemcell_path(infrastructure)
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
      ENV['BAT_INFRASTRUCTURE'] = infrastructure.name

      begin
        pipeline.download_stemcell('latest', infrastructure: infrastructure.name, name: 'micro-bosh-stemcell', light: infrastructure.light?)
        pipeline.download_stemcell('latest', infrastructure: infrastructure.name, name: 'bosh-stemcell', light: infrastructure.light?)

        infrastructure.run_system_micro_tests
      ensure
        pipeline.cleanup_stemcells
      end
    end

    private

    attr_reader :pipeline
  end
end
