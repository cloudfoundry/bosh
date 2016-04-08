require_relative './integration_example_group'

module Bosh::Spec
  class DeployHelper
    extend IntegrationExampleGroup
    extend IntegrationSandboxHelpers

    def self.start_deploy(manifest)
      output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)
      return Bosh::Spec::OutputParser.new(output).task_id('running')
    end

    def self.wait_for_task(task_id)
      output, success = director.task(task_id)
    end

    def self.wait_for_task_to_succeed(task_id)
      output, success = director.task(task_id)
      raise "task failed: #{output}" unless success
      output
    end
  end
end
