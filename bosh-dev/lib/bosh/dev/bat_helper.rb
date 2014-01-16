require 'bosh/dev/build'
require 'bosh/stemcell/definition'
require 'bosh/dev/aws/runner_builder'
require 'bosh/dev/openstack/runner_builder'
require 'bosh/dev/vsphere/runner_builder'

require 'forwardable'

module Bosh::Dev
  class BatHelper
    extend Forwardable
    def_delegators :@stemcell_definition, :infrastructure, :operating_system, :agent

    def self.for_rake_args(args)
      new(
        runner_builder_for_infrastructure_name(args.infrastructure_name),
        Bosh::Stemcell::Definition.for(args.infrastructure_name, args.operating_system_name, args.agent_name),
        Build.candidate,
        args.net_type,
      )
    end

    def self.runner_builder_for_infrastructure_name(name)
      { 'aws'       => Bosh::Dev::Aws::RunnerBuilder.new,
        'openstack' => Bosh::Dev::Openstack::RunnerBuilder.new,
        'vsphere'   => Bosh::Dev::VSphere::RunnerBuilder.new,
      }[name]
    end

    def initialize(runner_builder, stemcell_definition, build, net_type)
      @runner_builder   = runner_builder
      @stemcell_definition = stemcell_definition
      @build    = build
      @net_type = net_type
    end

    def bosh_stemcell_path
      build.bosh_stemcell_path(stemcell_definition, artifacts_dir)
    end

    def artifacts_dir
      File.join(
        '/tmp',
        'ci-artifacts',
        infrastructure.name,
        net_type ? net_type : '',
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

    def deploy_microbosh_and_run_bats
      prepare_directories
      build.download_stemcell(
        'bosh-stemcell',
        stemcell_definition,
        infrastructure.light?,
        artifacts_dir,
      )
      bats_runner.deploy_microbosh_and_run_bats
    end

    def run_bats
      bats_runner.run_bats
    end

    private

    attr_reader :build, :net_type, :stemcell_definition

    def prepare_directories
      FileUtils.rm_rf(artifacts_dir)
      FileUtils.mkdir_p(micro_bosh_deployment_dir)
    end

    def bats_runner
      @runner_builder.build(self, net_type)
    end
  end
end

