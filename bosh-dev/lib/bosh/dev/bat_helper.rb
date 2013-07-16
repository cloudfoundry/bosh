require 'bosh/dev/infrastructure'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class BatHelper
    attr_reader :workspace_dir
    attr_reader :infrastructure

    def initialize(workspace_dir, infrastructure)
      raise ArgumentError.new("invalid infrastructure: #{infrastructure}") unless Infrastructure::ALL.include?(infrastructure)

      @workspace_dir = workspace_dir
      @infrastructure = Infrastructure.new(infrastructure)
      @pipeline = Pipeline.new
    end

    def light?
      infrastructure.light?
    end

    def bosh_stemcell_path
      File.join(workspace_dir, @pipeline.latest_stemcell_filename(infrastructure.name, 'bosh-stemcell', light?))
    end

    def micro_bosh_stemcell_path
      File.join(workspace_dir, @pipeline.latest_stemcell_filename(infrastructure.name, 'micro-bosh-stemcell', light?))
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
      Dir.chdir(workspace_dir) do
        ENV['BAT_INFRASTRUCTURE'] = infrastructure.name

        begin
          @pipeline.download_latest_stemcell(infrastructure: infrastructure.name, name: 'micro-bosh-stemcell', light: light?)
          @pipeline.download_latest_stemcell(infrastructure: infrastructure.name, name: 'bosh-stemcell', light: light?)

          @infrastructure.run_system_micro_tests
        ensure
          cleanup_stemcells
        end
      end
    end

    def cleanup_stemcells
      FileUtils.rm_f(Dir.glob(File.join(workspace_dir, '*bosh-stemcell-*.tgz')))
    end
  end
end
