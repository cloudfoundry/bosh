require 'spec_helper'
require 'fileutils'

describe 'delete arp entries', type: :integration do
  with_reset_sandbox_before_each

  before do
    upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
    upload_stemcell
    create_and_upload_test_release
  end

  context 'it supports forceful removal of ARP cache entries' do
    it 'calls the delete_arp_entries action on all bosh-agents' do
      manifest_deployment1 = Bosh::Spec::Deployments.test_release_manifest_with_stemcell
      manifest_deployment1.merge!(
        'instance_groups' => [
          Bosh::Spec::Deployments.simple_instance_group(
            name: 'job_to_test_forceful_arp',
            instances: 1,
          ),
        ],
      )
      deploy_simple_manifest(manifest_hash: manifest_deployment1)

      agent_id0 = director.instance('job_to_test_forceful_arp', '0').agent_id

      manifest_deployment2 = Bosh::Spec::Deployments.test_release_manifest_with_stemcell
      manifest_deployment2.merge!(
        'name' => 'simple2',
        'instance_groups' => [Bosh::Spec::Deployments.simple_instance_group(instances: 1)],
      )

      deploy_simple_manifest(manifest_hash: manifest_deployment2)

      agent_log0 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id0}.log")

      expect(agent_log0).to include('Running sync action delete_arp_entries')
      expect(agent_log0).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.3"]')
    end
  end
end
