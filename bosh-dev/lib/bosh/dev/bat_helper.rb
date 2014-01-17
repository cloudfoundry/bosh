require 'bosh/dev/build'
require 'bosh/stemcell/definition'
require 'bosh/dev/aws/runner_builder'
require 'bosh/dev/openstack/runner_builder'
require 'bosh/dev/vsphere/runner_builder'
require 'bosh/dev/bat/artifacts'

require 'forwardable'

module Bosh::Dev
  class BatHelper
    extend Forwardable

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

      artifacts_path = File.join(
        '/tmp/ci-artifacts',
        infrastructure.name,
        net_type,
        operating_system.name,
        'deployments'
      )
      @artifacts = Bosh::Dev::Bat::Artifacts.new(artifacts_path, build, stemcell_definition)
    end

    def deploy_microbosh_and_run_bats
      artifacts.prepare_directories
      build.download_stemcell(
        'bosh-stemcell',
        stemcell_definition,
        infrastructure.light?,
        artifacts.path,
      )
      bats_runner.deploy_microbosh_and_run_bats
    end

    def run_bats
      bats_runner.run_bats
    end

    private
    attr_reader :build, :net_type, :stemcell_definition, :artifacts
    def_delegators :@stemcell_definition, :infrastructure, :operating_system

    def bats_runner
      @runner_builder.build(artifacts, net_type)
    end
  end
end

