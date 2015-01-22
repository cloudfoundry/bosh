require 'bosh/dev/build'
require 'bosh/stemcell/definition'
require 'bosh/stemcell/stemcell'
require 'bosh/dev/aws/runner_builder'
require 'bosh/dev/openstack/runner_builder'
require 'bosh/dev/vsphere/runner_builder'
require 'bosh/dev/vcloud/runner_builder'
require 'bosh/dev/bat/artifacts'

module Bosh::Dev
  class BatHelper
    def self.for_rake_args(args)
      definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, args.light == 'true')
      build = Build.candidate
      stemcell = Bosh::Stemcell::Stemcell.new(definition, 'bosh-stemcell', build.number, args.disk_format)

      artifacts_path = File.join(
        ENV.fetch('WORKSPACE', '/tmp'),
        'ci-artifacts',
        definition.infrastructure.name,
        args.net_type,
        definition.operating_system.name,
        definition.operating_system.version.to_s,
        definition.agent.name,
        'deployments'
      )
      artifacts = Bosh::Dev::Bat::Artifacts.new(artifacts_path, stemcell)

      new(
        runner_builder_for_infrastructure_name(args.infrastructure_name),
        artifacts,
        build,
        args.net_type,
        stemcell
      )
    end

    def self.runner_builder_for_infrastructure_name(name)
      { 'aws'       => Bosh::Dev::Aws::RunnerBuilder.new,
        'openstack' => Bosh::Dev::Openstack::RunnerBuilder.new,
        'vsphere'   => Bosh::Dev::VSphere::RunnerBuilder.new,
        'vcloud'    => Bosh::Dev::VCloud::RunnerBuilder.new,
      }[name]
    end

    def initialize(runner_builder, artifacts, build, net_type, stemcell)
      @runner_builder   = runner_builder
      @build    = build
      @net_type = net_type
      @stemcell = stemcell
      @artifacts = artifacts
    end

    def deploy_microbosh_and_run_bats
      deploy_bats_microbosh
      run_bats
    end

    def deploy_bats_microbosh
      artifacts.prepare_directories
      build.download_stemcell(
        stemcell,
        artifacts.path,
      )

      bats_runner.deploy_bats_microbosh
    end

    def run_bats
      bats_runner.run_bats
    end

    private
    attr_reader :build, :net_type, :artifacts, :stemcell

    def bats_runner
      @runner_builder.build(artifacts, net_type)
    end
  end
end

