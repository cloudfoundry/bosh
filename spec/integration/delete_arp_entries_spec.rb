require 'spec_helper'
require 'fileutils'

describe 'delete arp entries', type: :integration do
  with_reset_sandbox_before_each

  context 'it supports forceful removal of ARP cache entries' do
    before do
      target_and_login

      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      new_subnets = [Bosh::Spec::NetworkingManifest.make_subnet({
            :range => '192.168.2.0/24',
            :available_ips => 20
          })]
      new_network = {
        'name' => 'b',
        'subnets' => new_subnets
      }
      cloud_config_hash['networks'] << new_network

      upload_cloud_config({:cloud_config_hash => cloud_config_hash})
      upload_stemcell
      create_and_upload_test_release
    end

    context 'when there is only 1 deployment' do
      context 'when flush_arp is set in BOSH director config' do
        it 'calls the delete_arp_entries action on the bosh-agents' do
          manifest = Bosh::Spec::Deployments.test_release_manifest
          manifest['jobs'] = [Bosh::Spec::Deployments.simple_job(
              name: 'job_to_test_forceful_arp',
              instances: 2
            )]
          set_deployment(manifest_hash: manifest)
          deploy({})

          # This is above the second deploy so we get the first log file from the agent
          # as they get a new agent_id after they're brought down then up
          agent_id_1 = director.vm('job_to_test_forceful_arp', '1').agent_id

          # Change stemcell deployment (forces all VMs to update)
          upload_stemcell_2
          simple_cloud_config = Bosh::Spec::Deployments.simple_cloud_config
          simple_cloud_config['resource_pools'][0]['stemcell']["name"] = "centos-stemcell"
          simple_cloud_config['resource_pools'][0]['stemcell']["version"] = "2"
          upload_cloud_config(cloud_config_hash: simple_cloud_config)

          deploy({})

          agent_id_0 = director.vm('job_to_test_forceful_arp', '0').agent_id

          agent_log_0 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_0}.log")
          agent_log_1 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")

          expect(agent_log_0).to include("Running async action delete_arp_entries")
          expect(agent_log_1).to include("Running async action delete_arp_entries")
          expect(agent_log_0).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.3"]')
          expect(agent_log_1).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.2"]')
        end

        it 'calls delete_arp_entries action with multiple ip addresses' do
          job_with_networks = Bosh::Spec::Deployments.simple_job(
            name: 'job_to_test_forceful_arp',
            instances: 2
          )
          job_with_networks['networks'] = [
            { 'name' => 'a', 'default' => ["dns", "gateway"] },
            { 'name' => 'b' }
          ]

          manifest = Bosh::Spec::Deployments.test_release_manifest
          manifest['jobs'] = [job_with_networks]

          set_deployment(manifest_hash: manifest)

          deploy({})

          # This is above the second deploy so we get the first log file from the agent
          # as they get a new agent_id after they're brought down then up
          agent_id_1 = director.vm('job_to_test_forceful_arp', '1').agent_id

          # Change stemcell deployment (forces all VMs to update)
          upload_stemcell_2
          cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config_hash.merge!({
              'networks' => [
                Bosh::Spec::Deployments.network,
                Bosh::Spec::Deployments.network({
                    'name' => 'b',
                    'subnets' => [Bosh::Spec::NetworkingManifest.make_subnet({
                          :range => '192.168.2.0/24',
                          :available_ips => 20
                        })]
                  })]
            })
          cloud_config_hash['resource_pools'].first['stemcell'].merge!({"name" => "centos-stemcell", "version" => "2"})
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          deploy({})

          agent_log_1 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")

          expect(agent_log_1).to include("Running async action delete_arp_entries")
          expect(agent_log_1).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.2","192.168.2.2"]')
        end
      end

      context 'when max_in_flight is greater than 1' do
        it 'calls the delete_arp_entries action on the bosh-agents' do
          manifest = Bosh::Spec::Deployments.test_release_manifest
          manifest.merge!(
            {
              'jobs' => [Bosh::Spec::Deployments.simple_job(
                  name: 'job_to_test_forceful_arp',
                  instances: 3)]
            })
          manifest['update'].merge!({'max_in_flight'=>2})
          set_deployment(manifest_hash: manifest)

          deploy({})

          vms = director.vms
          index_ip_hash = Hash[*vms.map {|vm| [vm.index, vm.ips]}.flatten]
          agent_id_1 = director.vm('job_to_test_forceful_arp', '1').agent_id
          agent_id_2 = director.vm('job_to_test_forceful_arp', '2').agent_id


          # Change stemcell deployment (forces all VMs to update)
          upload_stemcell_2
          simple_cloud_config = Bosh::Spec::Deployments.simple_cloud_config
          simple_cloud_config['resource_pools'].first['stemcell'].merge!({"name" => "centos-stemcell", "version" => "2"})
          upload_cloud_config(cloud_config_hash: simple_cloud_config)

          deploy({})

          agent_id_0 = director.vm('job_to_test_forceful_arp', '0').agent_id
          agent_log_0 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_0}.log")

          agent_log_1 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")
          agent_log_2 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_2}.log")

          expect(agent_log_1).to include("Running async action delete_arp_entries")
          expect(agent_log_2).to include("Running async action delete_arp_entries")
          expect(agent_log_1).to include("\"method\":\"delete_arp_entries\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["0"]}\"]")
          expect(agent_log_2).to include("\"method\":\"delete_arp_entries\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["0"]}\"]")

          expect(agent_log_0).to include("Running async action delete_arp_entries")
          expect(agent_log_0).to include("\"method\":\"delete_arp_entries\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["1"]}\"]")
          expect(agent_log_0).to include("\"method\":\"delete_arp_entries\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["2"]}\"]")

        end
      end
    end

    context 'when there is more than 1 deployment' do
      context 'when flush_arp is set in the BOSH director config' do
        it 'calls the delete_arp_entries action on all bosh-agents' do
          manifest_deployment_1 = Bosh::Spec::Deployments.test_release_manifest
          manifest_deployment_1.merge!(
            {
              'jobs' => [Bosh::Spec::Deployments.simple_job(
                  name: 'job_to_test_forceful_arp',
                  instances: 1)]
            })
          set_deployment(manifest_hash: manifest_deployment_1)
          deploy({})

          agent_id_0 = director.vm('job_to_test_forceful_arp', '0').agent_id

          manifest_deployment_2 = Bosh::Spec::Deployments.test_release_manifest
          manifest_deployment_2.merge!(
            {
              'name' => 'simple2',
              'jobs' => [Bosh::Spec::Deployments.simple_job(
                  name: 'job_to_test_forceful_arp_2',
                  instances: 1)]
            })

          set_deployment(manifest_hash: manifest_deployment_2)
          deploy({})

          agent_log_0 = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_0}.log")

          expect(agent_log_0).to include("Running async action delete_arp_entries")
          expect(agent_log_0).to include('"method":"delete_arp_entries","arguments":[{"ips":["192.168.1.3"]')
        end
      end
    end
  end
end
