require 'spec_helper'

module Support
  module DeploymentHelpers
    def prepare_deploy(deployment_manifest)
      fake_job

      if deployment_manifest.key?('stemcells')
        Bosh::Director::Models::Stemcell.make(
          name: deployment_manifest['stemcells'].first['name'],
          version: deployment_manifest['stemcells'].first['version'],
        )
      end

      Bosh::Director::Config.dns = { 'address' => 'fake-dns-address' }

      release_model = Bosh::Director::Models::Release.make(name: deployment_manifest['releases'].first['name'])
      version = Bosh::Director::Models::ReleaseVersion.make(version: deployment_manifest['releases'].first['version'])
      release_model.add_version(version)

      return unless deployment_manifest.key?('instance_groups')

      deployment_manifest['instance_groups'].first['jobs'].each do |job|
        template_model = Bosh::Director::Models::Template.make(name: job['name'])
        version.add_template(template_model)
      end
    end

    def fake_job
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
    end
  end
end

RSpec.configure do |config|
  config.include(Support::DeploymentHelpers)
end
