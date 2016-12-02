require 'spec_helper'
require 'fileutils'

describe 'delete arp entries', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    upload_cloud_config({:cloud_config_hash => Bosh::Spec::Deployments.simple_cloud_config})
    upload_stemcell
    create_and_upload_test_release
  end

  context 'it supports forceful removal of ARP cache entries' do
    it 'calls the delete_arp_entries action on all bosh-agents' do
      manifest_deployment_1 = Bosh::Spec::Deployments.test_release_manifest
      manifest_deployment_1.merge!(
        {
          'jobs' => [Bosh::Spec::Deployments.simple_job(
              name: 'job_to_test_forceful_arp',
              instances: 1)]
        })
      deploy_simple_manifest(manifest_hash: manifest_deployment_1)

      agent_id_0 = director.vm('job_to_test_forceful_arp', '0').agent_id

      manifest_deployment_2 = Bosh::Spec::Deployments.test_release_manifest
      manifest_deployment_2.merge!(
        {
          'name' => 'simple2',
          'jobs' => [Bosh::Spec::Deployments.simple_job(instances: 1)]
        })

      deploy_simple_manifest(manifest_hash: manifest_deployment_2)

      agent_log_0 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_0}.log")

      expect(agent_log_0).to include('Running sync action delete_arp_entries')
      expect(agent_log_0).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.3"]')
    end
  end
end
