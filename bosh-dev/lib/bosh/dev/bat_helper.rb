require 'bosh/dev/build'
require 'bosh/stemcell/definition'
require 'bosh/dev/aws/runner_builder'
require 'bosh/dev/openstack/runner_builder'
require 'bosh/dev/vsphere/runner_builder'
require 'bosh/dev/bat/artifacts'

module Bosh::Dev
  class BatHelper
    def self.for_rake_args(args)
      new(
        runner_builder_for_infrastructure_name(args.infrastructure_name),
        Bosh::Stemcell::Definition.for(args.infrastructure_name, args.operating_system_name, 'ruby'),
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

    def initialize(runner_builder, microbosh_definition, bat_definition, build, net_type)
      @runner_builder   = runner_builder
      @microbosh_definition = microbosh_definition
      @bat_definition = bat_definition
      @build    = build
      @net_type = net_type

      artifacts_path = File.join(
        '/tmp/ci-artifacts',
        bat_definition.infrastructure.name,
        net_type,
        bat_definition.operating_system.name,
        bat_definition.agent.name,
        'deployments'
      )
      @artifacts = Bosh::Dev::Bat::Artifacts.new(artifacts_path, build, microbosh_definition, bat_definition)
    end

    def deploy_microbosh_and_run_bats
      artifacts.prepare_directories
      build.download_stemcell(
        'bosh-stemcell',
        bat_definition,
        bat_definition.infrastructure.light?,
        artifacts.path,
      )

      unless bat_definition == microbosh_definition
        build.download_stemcell(
          'bosh-stemcell',
          microbosh_definition,
          microbosh_definition.infrastructure.light?,
          artifacts.path,
        )
      end

      bats_runner.deploy_microbosh_and_run_bats
    end

    def run_bats
      bats_runner.run_bats
    end

    private
    attr_reader :build, :net_type, :microbosh_definition, :bat_definition, :artifacts

    def bats_runner
      @runner_builder.build(artifacts, net_type)
    end
  end
end

