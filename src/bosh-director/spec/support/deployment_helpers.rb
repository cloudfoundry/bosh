require 'spec_helper'

module Support
  module DeploymentHelpers
    def prepare_deploy(deployment_manifest, cloud_config_manifest)
      fake_job
      Bosh::Director::Models::Stemcell.make(
        name: cloud_config_manifest['resource_pools'].first['stemcell']['name'],
        version: cloud_config_manifest['resource_pools'].first['stemcell']['version']
      )

      Bosh::Director::Config.dns = {'address' => 'fake-dns-address'}

      release_model = Bosh::Director::Models::Release.make(name: deployment_manifest['releases'].first['name'])
      version = Bosh::Director::Models::ReleaseVersion.make(version: deployment_manifest['releases'].first['version'])
      release_model.add_version(version)

      template_model = Bosh::Director::Models::Template.make(name: deployment_manifest['jobs'].first['templates'].first['name'])
      version.add_template(template_model)
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
