require 'bosh/stemcell/infrastructure'
require 'bosh/dev/build'

module Bosh::Dev
  class BatHelper
    attr_reader :infrastructure, :operating_system

    def initialize(infrastructure_name, operating_system_name, net_type)
      @infrastructure   = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      @operating_system = Bosh::Stemcell::OperatingSystem.for(operating_system_name)
      @build    = Build.candidate
      @net_type = net_type
    end

    def bosh_stemcell_path
      build.bosh_stemcell_path(infrastructure, operating_system, artifacts_dir)
    end

    def artifacts_dir
      File.join(
        '/tmp',
        'ci-artifacts',
        infrastructure.name,
        operating_system.name,
        'deployments',
      )
    end

    def micro_bosh_deployment_dir
      File.join(artifacts_dir, micro_bosh_deployment_name)
    end

    def micro_bosh_deployment_name
      'microbosh'
    end

    def run_rake
      prepare_directories
      fetch_stemcells
      Rake::Task["spec:system:micro"].invoke(
        infrastructure.name,
        operating_system.name,
        net_type,
      )
    end

    private

    attr_reader :build, :net_type

    def prepare_directories
      FileUtils.rm_rf(artifacts_dir)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    def fetch_stemcells
      build.download_stemcell(
        name: 'bosh-stemcell',
        infrastructure: infrastructure,
        operating_system: operating_system,
        light: infrastructure.light?,
        output_directory: artifacts_dir,
      )
    end
  end
end

