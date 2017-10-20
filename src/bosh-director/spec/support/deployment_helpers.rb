require 'spec_helper'

module Support
  module DeploymentHelpers
    def prepare_deploy(deployment_manifest)
      fake_job

      if deployment_manifest.has_key?('resource_pools')
        Bosh::Director::Models::Stemcell.make(
          name: deployment_manifest['resource_pools'].first['stemcell']['name'],
          version: deployment_manifest['resource_pools'].first['stemcell']['version']
        )
      elsif deployment_manifest.has_key?('stemcells')
        Bosh::Director::Models::Stemcell.make(
          name: deployment_manifest['stemcells'].first['name'],
          version: deployment_manifest['stemcells'].first['version']
        )
      end

      Bosh::Director::Config.dns = { 'address' => 'fake-dns-address' }

      release_model = Bosh::Director::Models::Release.make(name: deployment_manifest['releases'].first['name'])
      version = Bosh::Director::Models::ReleaseVersion.make(version: deployment_manifest['releases'].first['version'])
      release_model.add_version(version)

      if deployment_manifest.has_key?('jobs')
        template_model = Bosh::Director::Models::Template.make(name: deployment_manifest['jobs'].first['templates'].first['name'])
        version.add_template(template_model)
      elsif deployment_manifest.has_key?('instance_groups')
        template_model = Bosh::Director::Models::Template.make(name: deployment_manifest['instance_groups'].first['jobs'].first['name'])
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
