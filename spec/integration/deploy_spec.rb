require 'spec_helper'
require 'fileutils'

describe 'deploy', type: :integration do
  with_reset_sandbox_before_each

  it 'allows removing deployed jobs and adding new jobs at the same time' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_from_scratch(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name1' => 3)

    manifest_hash['jobs'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name2' => 3)

    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name1' => 3)
  end

  context 'when stemcell is specified with an OS' do
    it 'deploys with the stemcell with specified OS and version' do
      target_and_login
      create_and_upload_test_release

      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash['resource_pools'].first['stemcell'].delete('name')
      cloud_config_hash['resource_pools'].first['stemcell']['os'] = 'toronto-os'
      cloud_config_hash['resource_pools'].first['stemcell']['version'] = '1'

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      stemcell_id = current_sandbox.cpi.all_stemcells[0]['id']

      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_v2.tgz')} --skip-if-exists")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1
      deploy_simple_manifest(manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method("create_vm")
      expect(create_vm_invocations.count).to be > 0

      create_vm_invocations.each do |invocation|
        expect(invocation['inputs']['stemcell_id']).to eq(stemcell_id)
      end

    end
  end

  context 'when stemcell is using latest version' do
    it 'redeploys with latest version of stemcell' do
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config['resource_pools'].first['stemcell']['version'] = 'latest'
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1

      target_and_login
      create_and_upload_test_release
      upload_cloud_config(cloud_config_hash: cloud_config)

      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      stemcell_1 = table(bosh_runner.run('stemcells')).last
      expect(stemcell_1['Version']).to eq('1')

      deploy_simple_manifest(manifest_hash: manifest_hash)
      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      initial_count = invocations.count
      expect(initial_count).to be > 1
      expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell_1['CID'])

      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_v2.tgz')} --skip-if-exists")
      stemcell_2 = table(bosh_runner.run('stemcells')).last
      expect(stemcell_2['Version']).to eq('2')

      deploy_simple_manifest(manifest_hash: manifest_hash)
      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations.count).to be > initial_count
      expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell_2['CID'])
    end
  end

  it 'deployment fails when starting task fails' do
    deploy_from_scratch
    director.vm('foobar', '0').fail_start_task
    _, exit_code = deploy(failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
  end

  context 'when using legacy deployment configuration' do
    let(:legacy_manifest_hash ) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(Bosh::Spec::Deployments.simple_cloud_config)
      manifest_hash['resource_pools'].find{ |i| i['name'] == 'a' }['size'] = 5
      manifest_hash
    end

    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
    end

    context 'when a could config is uploaded' do
      it 'returns an error if deployment manifest contains cloud properties' do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'].find{ |i| i['name'] == 'a' }['size'] = 4

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        output = deploy_simple_manifest(manifest_hash: legacy_manifest_hash, failure_expected: true)
        expect(output).to include('Deployment manifest should not contain cloud config properties')
      end
    end

    context 'when no cloud config is uploaded' do
      it 'respects the cloud related configurations in the deployment manifest' do
        deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

        expect_running_vms_with_names_and_count('foobar' => 3)
        expect_table('deployments', %(
          +--------+----------------------+-------------------+--------------+
          | Name   | Release(s)           | Stemcell(s)       | Cloud Config |
          +--------+----------------------+-------------------+--------------+
          | simple | bosh-release/0+dev.1 | ubuntu-stemcell/1 | none         |
          +--------+----------------------+-------------------+--------------+
        ))
      end
    end
  end

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
        it 'calls the delete_from_arp action on the bosh-agents' do
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

          expect(agent_log_0).to include("Running async action delete_from_arp")
          expect(agent_log_1).to include("Running async action delete_from_arp")
          expect(agent_log_0).to include('"method":"delete_from_arp","arguments":[{"ips":["192.168.1.3"]')
          expect(agent_log_1).to include('"method":"delete_from_arp","arguments":[{"ips":["192.168.1.2"]')
        end

        it 'calls delete_from_arp action with multiple ip addresses' do
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

          expect(agent_log_1).to include("Running async action delete_from_arp")
          expect(agent_log_1).to include('"method":"delete_from_arp","arguments":[{"ips":["192.168.1.2","192.168.2.2"]')
        end
      end

      context 'when max_in_flight is greater than 1' do
        it 'calls the delete_from_arp action on the bosh-agents' do
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

          expect(agent_log_1).to include("Running async action delete_from_arp")
          expect(agent_log_2).to include("Running async action delete_from_arp")
          expect(agent_log_1).to include("\"method\":\"delete_from_arp\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["0"]}\"]")
          expect(agent_log_2).to include("\"method\":\"delete_from_arp\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["0"]}\"]")

          expect(agent_log_0).to include("Running async action delete_from_arp")
          expect(agent_log_0).to include("\"method\":\"delete_from_arp\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["1"]}\"]")
          expect(agent_log_0).to include("\"method\":\"delete_from_arp\",\"arguments\":[{\"ips\":[\"#{index_ip_hash["2"]}\"]")

        end
      end
    end

    context 'when there is more than 1 deployment' do
      context 'when flush_arp is set in the BOSH director config' do
        it 'calls the delete_from_arp action on all bosh-agents' do
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

          expect(agent_log_0).to include("Running async action delete_from_arp")
          expect(agent_log_0).to include('"method":"delete_from_arp","arguments":[{"ips":["192.168.1.3"]')
        end
      end
    end
  end

  context 'it supports running pre-start scripts' do
    before do
      target_and_login
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      upload_stemcell
    end

    context 'when the pre-start scripts are valid' do
      before do
        create_and_upload_test_release
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_templates_having_prestart_scripts',
                               templates: [
                                   {'name' => 'job_1_with_pre_start_script'},
                                   {'name' => 'job_2_with_pre_start_script'}
                               ],
                               instances: 1)]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'runs the pre-start scripts on the agent vm, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
        deploy({})

        agent_id = director.vm('job_with_templates_having_prestart_scripts', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_1_with_pre_start_script/bin/pre-start' script has successfully executed")
        expect(agent_log).to include("/jobs/job_2_with_pre_start_script/bin/pre-start' script has successfully executed")

        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        expect(job_1_stdout).to match("message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1")

        job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stderr.log")
        expect(job_1_stderr).to match('message on stderr of job 1 pre-start script')

        job_2_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_pre_start_script/pre-start.stdout.log")
        expect(job_2_stdout).to match('message on stdout of job 2 pre-start script')
      end
    end

    it 'should append the logs to the previous pre-start logs' do
      manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
          {
              'releases' => [{
                                 'name'    => 'release_with_prestart_script',
                                 'version' => '1',
                             }],
              'jobs' => [
                  Bosh::Spec::Deployments.job_with_many_templates(
                      name: 'job_with_templates_having_prestart_scripts',
                      templates: [
                          {'name' => 'job_1_with_pre_start_script'}
                      ],
                      instances: 1)]
          })
      set_deployment(manifest_hash: manifest)
      bosh_runner.run("upload release #{spec_asset('pre_start_script_releases/release_with_prestart_script-1.tgz')}")
      deploy({})

      # re-upload a different release version to make the pre-start scripts run
      manifest['releases'][0]['version'] = '2'
      set_deployment(manifest_hash: manifest)
      bosh_runner.run("upload release #{spec_asset('pre_start_script_releases/release_with_prestart_script-2.tgz')}")
      deploy({})

      agent_id = director.vm('job_with_templates_having_prestart_scripts', '0').agent_id
      job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
      job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stderr.log")

      expect(job_1_stdout).to match_output %(
        message on stdout of job 1 pre-start script
        template interpolation works in this script: this is pre_start_message_1
        message on stdout of job 1 new version pre-start script
      )

      expect(job_1_stderr).to match_output %(
        message on stderr of job 1 pre-start script
        message on stderr of job 1 new version pre-start script
      )
    end

    context 'when the pre-start scripts are corrupted' do

      before do
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'releases' => [{
                                   'name'    => 'release_with_corrupted_pre_start',
                                   'version' => '1',
                               }],
                'jobs' => [
                    Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_templates_having_prestart_scripts',
                               templates: [
                                   {'name' => 'job_with_valid_pre_start_script'},
                                   {'name' => 'job_with_corrupted_pre_start_script'}
                               ],
                               instances: 1)]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'error out if run_script errors, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
        bosh_runner.run("upload release #{spec_asset('pre_start_script_releases/release_with_corrupted_pre_start-1.tgz')}")
        expect{
          deploy({})
        }.to raise_error(RuntimeError, /result: 1 of 2 pre-start scripts failed. Failed Jobs: job_with_corrupted_pre_start_script. Successful Jobs: job_with_valid_pre_start_script./)

        agent_id = director.vm('job_with_templates_having_prestart_scripts', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_with_valid_pre_start_script/bin/pre-start' script has successfully executed")
        expect(agent_log).to include("/jobs/job_with_corrupted_pre_start_script/bin/pre-start' script has failed with error")

        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_valid_pre_start_script/pre-start.stdout.log")
        expect(job_1_stdout).to match('message on stdout of job_with_valid_pre_start_script pre-start script')

        job_corrupted_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_corrupted_pre_start_script/pre-start.stdout.log")
        expect(job_corrupted_stdout).to match('message on stdout of job_with_corrupted_pre_start_script pre-start script')

        job_corrupted_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_corrupted_pre_start_script/pre-start.stderr.log")
        expect(job_corrupted_stderr).not_to be_empty
      end
    end
  end

  context 'it supports running post-deploy scripts' do
    with_reset_sandbox_before_each(enable_post_deploy: true)
    before do
      target_and_login
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      upload_stemcell
    end

    context 'when the post-deploy scripts are valid' do
      before do
        create_and_upload_test_release
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_post_deploy_script',
                               templates: [
                                   {'name' => 'job_1_with_post_deploy_script'},
                                   {'name' => 'job_2_with_post_deploy_script'}
                               ],
                               instances: 1),
                           Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'another_job_with_post_deploy_script',
                               templates: [
                                   {'name' => 'job_1_with_post_deploy_script'},
                                   {'name' => 'job_2_with_post_deploy_script'}
                               ],
                               instances: 1)]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'runs the post-deploy scripts on the agent vm, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
        deploy({})

        agent_id = director.vm('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        expect(agent_log).to include("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed")

        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(job_1_stdout).to match("message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1")

        job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stderr.log")
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        job_2_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_post_deploy_script/post-deploy.stdout.log")
        expect(job_2_stdout).to match('message on stdout of job 2 post-deploy script')
      end

      it 'runs does not run post-deploy scripts on stopped vms' do
        deploy({})

        agent_id_1 = director.vm('job_with_post_deploy_script', '0').agent_id
        agent_id_2 = director.vm('another_job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_2}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

        stop_job("another_job_with_post_deploy_script/0")

        agent_id_1 = director.vm('job_with_post_deploy_script', '0').agent_id
        agent_id_2 = director.vm('another_job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(2)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(2)

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_2}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
      end

      it 'runs the post-deploy script when a vms is resurrected', hm: true do
        current_sandbox.with_health_monitor_running do
          deploy({})

          agent_id = director.vm('job_with_post_deploy_script', '0').agent_id
          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

          resurected_vm = director.kill_vm_and_wait_for_resurrection(director.vm('job_with_post_deploy_script', '0'))

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{resurected_vm.agent_id}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        end
      end
    end

    context 'when the post-deploy scripts exit with error' do
      before do
        create_and_upload_test_release
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_post_deploy_script',
                               templates: [
                                   {'name' => 'job_1_with_post_deploy_script'},
                                   {'name' => 'job_3_with_broken_post_deploy_script'}
                               ],
                               instances: 1)]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'exits with error if post-deploy errors, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
        expect{deploy({})}.to raise_error(RuntimeError, /result: 1 of 2 post-deploy scripts failed. Failed Jobs: job_3_with_broken_post_deploy_script. Successful Jobs: job_1_with_post_deploy_script./)

        agent_id = director.vm('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        expect(agent_log).to include("/jobs/job_3_with_broken_post_deploy_script/bin/post-deploy' script has failed with error")

        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(job_1_stdout).to match("message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1")

        job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stderr.log")
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        job_3_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_3_with_broken_post_deploy_script/post-deploy.stdout.log")
        expect(job_3_stdout).to match('message on stdout of job 3 post-deploy script')

        job_3_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_3_with_broken_post_deploy_script/post-deploy.stderr.log")
        expect(job_3_stderr).not_to be_empty
      end
    end

    context 'when nothing has changed in the deployment it does not run the post-deploy script' do
      before do
        create_and_upload_test_release
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_post_deploy_script',
                               templates: [
                                   {'name' => 'job_1_with_post_deploy_script'},
                                   {'name' => 'job_2_with_post_deploy_script'}
                               ],
                               instances: 1),
                           Bosh::Spec::Deployments.job_with_many_templates(
                               name: 'job_with_errand',
                               templates: [
                                   {'name' => 'errand1'}
                               ],
                               instances: 1,
                               lifecycle: 'errand')]
            })
        set_deployment(manifest_hash: manifest)

      end

      it 'should not run the post deploy script if no changes have been made in deployment' do
        deploy({})
        agent_id = director.vm('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

        deploy({})
        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
      end

      it 'should not run post deploy script on jobs with no vm_cid' do
        deploy({})
        agent_id = director.vm('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(job_1_stdout).to match("message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1")

        job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stderr.log")
        expect(job_1_stderr).to match('message on stderr of job 1 post-deploy script')

        expect(File.file?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_with_errand/post-deploy.stdout.log")).to be_falsey
      end
    end
  end

  context 'it does not support running post-deploy scripts' do
    before do
      target_and_login
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      upload_stemcell

      create_and_upload_test_release
      manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
          {
              'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                             name: 'job_with_post_deploy_script',
                             templates: [
                                 {'name' => 'job_1_with_post_deploy_script'},
                                 {'name' => 'job_2_with_post_deploy_script'}
                             ],
                             instances: 1),
                         Bosh::Spec::Deployments.job_with_many_templates(
                             name: 'another_job_with_post_deploy_script',
                             templates: [
                                 {'name' => 'job_1_with_post_deploy_script'},
                                 {'name' => 'job_2_with_post_deploy_script'}
                             ],
                             instances: 1)]
          })
      set_deployment(manifest_hash: manifest)
    end

    it 'runs the post-deploy scripts on the agent vm, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
      deploy({})

      agent_id = director.vm('job_with_post_deploy_script', '0').agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to_not include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
      expect(agent_log).to_not include("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed")

      expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")).to be_falsey
      expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stderr.log")).to be_falsey
      expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_post_deploy_script/post-deploy.stdout.log")).to be_falsey
    end
  end

  context 'when deployment manifest has local templates properties defined' do
    before do
      target_and_login
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      upload_stemcell
      create_and_upload_test_release
      manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
          {
              'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                  name: 'job_with_templates_having_properties',
                  templates: [
                      {'name' => 'job_1_with_many_properties',
                       'properties' => {
                           'smurfs' => {
                               'color' => 'red'
                           },
                           'gargamel' => {
                               'color' => 'black'
                           }
                       }
                      },
                      {'name' => 'job_2_with_many_properties'}
                  ],
                  instances: 1,
                  properties: {
                      'snoopy' => 'happy',
                      'smurfs' => {
                          'color' => 'yellow'
                      },
                      'gargamel' => {
                          'color' => 'blue'
                      }
                  })]
          })
      set_deployment(manifest_hash: manifest)
    end

    it 'these templates should use the properties defined in their scope' do
      deploy({})
      target_vm = director.vm('job_with_templates_having_properties', '0')
      template_1 = YAML.load(target_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      template_2 = YAML.load(target_vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

      expect(template_1['properties_list']['smurfs_color']).to eq('red')
      expect(template_1['properties_list']['gargamel_color']).to eq('black')

      expect(template_2['properties_list']['smurfs_color']).to eq('yellow')
      expect(template_2['properties_list']['gargamel_color']).to eq('blue')
    end

    it 'should update the job when template properties change' do
      deploy({})

      manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
          {
              'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                  name: 'job_with_templates_having_properties',
                  templates: [
                      {'name' => 'job_1_with_many_properties',
                       'properties' => {
                           'smurfs' => {
                               'color' => 'reddish'
                           },
                           'gargamel' => {
                               'color' => 'blackish'
                           }
                       }
                      },
                      {'name' => 'job_2_with_many_properties'}
                  ],
                  instances: 1,
                  properties: {
                      'snoopy' => 'happy',
                      'smurfs' => {
                          'color' => 'yellow'
                      },
                      'gargamel' => {
                          'color' => 'blue'
                      }
                  })]
          })
      set_deployment(manifest_hash: manifest)

      output = deploy({})
      expect(output).to include("Started updating job job_with_templates_having_properties")
    end

    it 'should not update the job when template properties are the same' do
      deploy({})
      output = deploy({})
      expect(output).to_not include("Started updating job job_with_templates_having_properties")
    end


    context 'when the template has local properties defined but missing some of them' do
      before do
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                    name: 'job_with_templates_having_properties',
                    templates: [
                        {'name' => 'job_1_with_many_properties',
                         'properties' => {
                             'smurfs' => {
                                 'color' => 'red'
                             }
                         }
                        },
                        {'name' => 'job_2_with_many_properties'}
                    ],
                    instances: 1,
                    properties: {
                        'snoopy' => 'happy',
                        'smurfs' => {
                            'color' => 'yellow'
                        },
                        'gargamel' => {
                            'color' => 'black'
                        }
                    })]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'should fail even if the properties are defined outside the template scope' do
        output, exit_code = deploy(failure_expected: true, return_exit_code: true)

        expect(exit_code).to_not eq(0)
        expect(output).to include <<-EOF
Error 100: Unable to render instance groups for deployment. Errors are:
   - Unable to render jobs for instance group 'job_with_templates_having_properties'. Errors are:
     - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
       - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
        EOF
      end
    end

    context 'when multiple templates has local properties' do
      before do
        manifest = Bosh::Spec::Deployments.test_release_manifest.merge(
            {
                'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                    name: 'job_with_templates_having_properties',
                    templates: [
                        {'name' => 'job_1_with_many_properties',
                         'properties' => {
                             'smurfs' => {
                                 'color' => 'pink'
                             },
                             'gargamel' => {
                                 'color' => 'orange'
                             }
                         }
                        },
                        {'name' => 'job_2_with_many_properties',
                         'properties' => {
                             'smurfs' => {
                                 'color' => 'brown'
                             },
                             'gargamel' => {
                                 'color' => 'purple'
                             }
                         }
                        }
                    ],
                    instances: 1,
                    properties: {
                        'snoopy' => 'happy',
                        'smurfs' => {
                            'color' => 'yellow'
                        },
                        'gargamel' => {
                            'color' => 'black'
                        }
                    })]
            })
        set_deployment(manifest_hash: manifest)
      end

      it 'should not cross reference them' do
        deploy({})
        target_vm = director.vm('job_with_templates_having_properties', '0')
        template_1 = YAML.load(target_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        template_2 = YAML.load(target_vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

        expect(template_1['properties_list']['smurfs_color']).to eq('pink')
        expect(template_1['properties_list']['gargamel_color']).to eq('orange')

        expect(template_2['properties_list']['smurfs_color']).to eq('brown')
        expect(template_2['properties_list']['gargamel_color']).to eq('purple')
      end
    end

    context 'when same template is referenced in multiple deployment jobs' do

      let (:manifest) do
        Bosh::Spec::Deployments.test_release_manifest.merge(
          {
              'jobs' => [
                  Bosh::Spec::Deployments.job_with_many_templates(
                      name: 'worker_1',
                      templates: [
                          {'name' => 'job_1_with_many_properties',
                           'properties' => {
                               'smurfs' => {
                                   'color' => 'pink'
                               },
                               'gargamel' => {
                                   'color' => 'orange'
                               }
                           }
                          },
                          {'name' => 'job_2_with_many_properties',
                           'properties' => {
                               'smurfs' => {
                                   'color' => 'yellow'
                               },
                               'gargamel' => {
                                   'color' => 'green'
                               }
                           }
                          }
                      ],
                      instances: 1
                  ),
                  Bosh::Spec::Deployments.job_with_many_templates(
                      name: 'worker_2',
                      templates: [
                          {'name' => 'job_1_with_many_properties',
                           'properties' => {
                               'smurfs' => {
                                   'color' => 'navy'
                               },
                               'gargamel' => {
                                   'color' => 'red'
                               }
                           }
                          },
                          {'name' => 'job_2_with_many_properties'}
                      ],
                      instances: 1,
                      properties: {
                          'snoopy' => 'happy',
                          'smurfs' => {
                              'color' => 'brown'
                          },
                          'gargamel' => {
                              'color' => 'grey'
                          }
                      }
                  )
              ]
          })
      end

      it 'should not expose the local properties across deployment jobs' do
        set_deployment(manifest_hash: manifest)
        deploy({})

        target_vm_1 = director.vm('worker_1', '0')
        template_1_in_worker_1 = YAML.load(target_vm_1.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        template_2_in_worker_1 = YAML.load(target_vm_1.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

        target_vm_2 = director.vm('worker_2', '0')
        template_1_in_worker_2 = YAML.load(target_vm_2.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        template_2_in_worker_2 = YAML.load(target_vm_2.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

        expect(template_1_in_worker_1['properties_list']['smurfs_color']).to eq('pink')
        expect(template_1_in_worker_1['properties_list']['gargamel_color']).to eq('orange')
        expect(template_2_in_worker_1['properties_list']['smurfs_color']).to eq('yellow')
        expect(template_2_in_worker_1['properties_list']['gargamel_color']).to eq('green')

        expect(template_1_in_worker_2['properties_list']['smurfs_color']).to eq('navy')
        expect(template_1_in_worker_2['properties_list']['gargamel_color']).to eq('red')
        expect(template_2_in_worker_2['properties_list']['smurfs_color']).to eq('brown')
        expect(template_2_in_worker_2['properties_list']['gargamel_color']).to eq('grey')
      end

      it 'should only complain about non-property satisfied template when missing properties' do
        manifest['jobs'][1]['properties'] = {}
        set_deployment(manifest_hash: manifest)

        output, exist_code = deploy({return_exit_code: true, failure_expected: true})

        expect(exist_code).to_not eq(0)
        expect(output).to include <<-EOF
Error 100: Unable to render instance groups for deployment. Errors are:
   - Unable to render jobs for instance group 'worker_2'. Errors are:
     - Unable to render templates for job 'job_2_with_many_properties'. Errors are:
       - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
        EOF
      end
    end
  end

  it 'supports scaling down and then scaling up' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

    manifest_hash['jobs'].first['instances'] = 3
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 3)

    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 2)

    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 4)
  end

  it 'supports dynamically sized resource pools' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 3

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 3)

    # scale down
    manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 1)

    # scale up, below original size
    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 2)

    # scale up, above original size
    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 4)
  end

  it 'outputs properly formatted deploy information' do
    # We need to keep this test since the output is not tested and
    # keeps breaking.

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    output = deploy_from_scratch(manifest_hash: manifest_hash)

    duration_regex = '\\d\\d:\\d\\d:\\d\\d'
    step_duration_regex = '\\(' + duration_regex + '\\)'
    date_regex = '\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d UTC'
    sha_regex = '[0-9a-z]+'
    task_regex = '\\d+'
    uuid_regex = '[0-9a-f]{8}-[0-9a-f-]{27}'

    # order for creating missing vms is not guaranteed (running in parallel)
    expect(output).to match(strip_heredoc <<-OUT)
Director task #{task_regex}
  Started preparing deployment > Preparing deployment. Done #{step_duration_regex}

  Started preparing package compilation > Finding packages to compile. Done #{step_duration_regex}

  Started compiling packages
  Started compiling packages > foo/#{sha_regex}. Done #{step_duration_regex}
  Started compiling packages > bar/#{sha_regex}. Done #{step_duration_regex}
     Done compiling packages #{step_duration_regex}

  Started creating missing vms > foobar/0 \\(#{uuid_regex}\\). Done #{step_duration_regex}

  Started updating job foobar > foobar/0 \\(#{uuid_regex}\\) \\(canary\\). Done #{step_duration_regex}

Task #{task_regex} done

Started		#{date_regex}
Finished	#{date_regex}
Duration	#{duration_regex}

Deployed 'simple' to 'Test Director'
    OUT
  end

  context 'it supports compiled releases' do
    context 'release and stemcell have been uploaded' do
      before {
        target_and_login
        bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
        bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      }

      context 'it uploads the compiled release when there is no corresponding stemcell' do
        it 'should not raise an error' do
          bosh_runner.run('delete stemcell bosh-aws-xen-hvm-centos-7-go_agent 3001')
          bosh_runner.run('delete release test_release')
          expect {
            bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
          }.to_not raise_exception
          out = bosh_runner.run('inspect release test_release/1')
          expect(out).to include('| pkg_1                    | 16b4c8ef1574b3f98303307caad40227c208371f | (no source)   |                                      |                                          |
|                          |                                          | centos-7/3001 |')
        end
      end

      context 'when older compiled and newer non-compiled (source release) versions of the same release are uploaded' do
        before {
          cloud_config_with_centos = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config_with_centos['resource_pools'][0]['stemcell']['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
          cloud_config_with_centos['resource_pools'][0]['stemcell']['version'] = '3001'
          upload_cloud_config(:cloud_config_hash => cloud_config_with_centos)
        }

        context 'and they contain identical packages' do
          before {
            bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-4-same-packages-as-1.tgz')}")
            deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')
            deployment_manifest['releases'][0]['version'] = '4'
            set_deployment({manifest_hash: deployment_manifest })
          }

          it 'does not compile any packages' do
            out = deploy({})

            expect(out).to_not include('Started compiling packages')
          end
        end

        context 'and they contain one different package' do
          before {
            bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')}")
            deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')
            deployment_manifest['releases'][0]['version'] = '3'
            set_deployment({manifest_hash: deployment_manifest })
          }

          it 'compiles only the package with the different version and those that depend on it' do
            out = deploy({})
            expect(out).to include('Started compiling packages > pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
            expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

            expect(out).to_not include('Started compiling packages > pkg_2/')
            expect(out).to_not include('Started compiling packages > pkg_3_depends_on_2/')
            expect(out).to_not include('Started compiling packages > pkg_4_depends_on_3/')
          end
        end

        context 'when deploying with a stemcell that does not match the compiled release' do
          before {
            # switch deployment to use "ubuntu-stemcell/1"
            bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
            upload_cloud_config
            set_deployment({manifest_hash: Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5') })
          }

          it 'fails with an error message saying there is no way to compile for that stemcell' do
            out = deploy(failure_expected: true)
            expect(out).to include("Error 60001:")

            expect(out).to match_output %(
              Can't use release 'test_release/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
               - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
               - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
               - 'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c'
               - 'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4'
               - 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4'
            )
          end

          context 'and multiple releases are referenced in the current deployment' do
            before {
              bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release_a-1-on-centos-7-stemcell-3001.tgz')}")
              set_deployment({manifest_hash: Bosh::Spec::Deployments.test_deployment_manifest_referencing_multiple_releases})
            }

            it 'fails with an error message saying there is no way to compile the releases for that stemcell' do
              out = deploy(failure_expected: true)
              expect(out).to include("Error 60001:")

              expect(out).to match_output %(
                Can't use release 'test_release/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
                 - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
                 - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
              )

              expect(out).to match_output %(
                Can't use release 'test_release_a/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
                 - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
                 - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
                 - 'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c'
                 - 'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4'
                 - 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4'
              )
            end
          end
        end
      end
    end

    context 'it exercises the entire compiled release lifecycle' do
      it 'exports, deletes deployment & stemcell, uploads compiled, uploads patch-level stemcell, deploys' do
        target_and_login
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'][0]['stemcell']['version'] = 'latest'
        upload_cloud_config({:cloud_config_hash => cloud_config_hash})

        bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

        [
          'jobs/job_with_blocking_compilation',
          'packages/blocking_package',
          'jobs/fails_with_too_much_output',
          'packages/fails_with_too_much_output',
        ].each do |release_path|
          FileUtils.rm_rf(File.join(ClientSandbox.test_release_dir, release_path))
        end

        create_and_upload_test_release(:force => true)

        set_deployment({
                         manifest_hash: Bosh::Spec::Deployments.test_release_manifest.merge(
                           {
                             'jobs' => [
                               {
                                 'name' => 'job_with_many_packages',
                                 'templates' => [
                                   {
                                     'name' => 'job_with_many_packages'
                                   }
                                 ],
                                 'resource_pool' => 'a',
                                 'instances' => 1,
                                 'networks' => [{'name' => 'a'}],
                               }
                             ]
                           }
                         )
                       })
        deploy({})

        bosh_runner.run('export release bosh-release/0.1-dev toronto-os/1')

        bosh_runner.run('delete deployment simple')
        bosh_runner.run('delete release bosh-release')
        bosh_runner.run('delete stemcell ubuntu-stemcell 1')

        bosh_runner.run("upload release #{File.join(Bosh::Dev::Sandbox::Workspace.dir, 'client-sandbox', 'bosh_work_dir')}/release-bosh-release-0.1-dev-on-toronto-os-stemcell-1.tgz")
        bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_1_1.tgz')}")

        create_call_count = current_sandbox.cpi.invocations_for_method('create_vm').size
        deploy({})
        expect(current_sandbox.cpi.invocations_for_method('create_vm').size).to eq(create_call_count + 1)
      end
    end
  end

  context 'when the deployment manifest file is large' do
    before do
      release_filename = spec_asset('test_release.tgz')

      minimal_manifest = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.minimal_manifest)
      minimal_manifest["properties"] = {}
      for i in 0..10000
        minimal_manifest["properties"]["property#{i}"] = "value#{i}"
      end

      deployment_manifest = yaml_file('minimal', minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)

      target_and_login
      bosh_runner.run("upload release #{release_filename}")
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
    end

    it 'deploys successfully' do
      output, exit_code = bosh_runner.run('deploy', return_exit_code: true)
      expect(output).to include("Deployed 'minimal' to")
      expect(exit_code).to eq(0)
    end
  end

  context 'when errand jobs are used' do
    let(:manifest) {
      Bosh::Spec::Deployments.test_release_manifest.merge({
        'jobs' => [
          Bosh::Spec::Deployments.job_with_many_templates(
            name: 'job_with_post_deploy_script',
            templates: [
              {'name' => 'job_1_with_post_deploy_script'},
              {'name' => 'job_2_with_post_deploy_script'}
            ],
            instances: 1),
          Bosh::Spec::Deployments.simple_errand_job.merge({
              'name' => 'alive-errand',
            }),
          Bosh::Spec::Deployments.simple_errand_job.merge({
              'name' => 'dead-errand',
            }),
        ]
      })
    }

    before do
      prepare_for_deploy()
      deploy_simple_manifest(manifest_hash: manifest)
    end

    context 'when errand has been run with --keep-alive' do
      it 'immediately updates the errand job' do
        bosh_runner.run('download manifest simple')

        bosh_runner.run('run errand alive-errand --keep-alive')

        job_with_post_deploy_script_vm = director.vm('job_with_post_deploy_script', '0')
        expect(File.exists?(job_with_post_deploy_script_vm.file_path('jobs/foobar/monit'))).to be_falsey

        job_with_errand_vm = director.vm('alive-errand', '0')
        expect(File.exists?(job_with_errand_vm.file_path('jobs/errand1/bin/run'))).to be_truthy
        expect(File.exists?(job_with_errand_vm.file_path('jobs/foobar/monit'))).to be_falsey

        new_manifest = manifest
        new_manifest['jobs'][0]['templates'] << {'name' => 'foobar'}
        new_manifest['jobs'][1]['templates'] << {'name' => 'foobar'}
        new_manifest['jobs'][2]['templates'] << {'name' => 'foobar'}
        deploy_simple_manifest(manifest_hash: new_manifest)

        job_with_post_deploy_script_vm = director.vm('job_with_post_deploy_script', '0')
        expect(File.exists?(job_with_post_deploy_script_vm.file_path('jobs/foobar/monit'))).to be_truthy

        job_with_errand_vm = director.vm('alive-errand', '0')
        expect(File.exists?(job_with_errand_vm.file_path('jobs/foobar/monit'))).to be_truthy

        expect {
          director.vm('dead-errand', '0')
        }.to raise_error(RuntimeError, 'Failed to find vm dead-errand/0')
      end
    end
  end

  it 'saves instance name, deployment name, az, and id to the file system on the instance' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    manifest_hash['jobs'].first['azs'] = ['zone-1']

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [
        {'name' => 'zone-1', 'cloud_properties' => {}},
    ]
    cloud_config_hash['compilation']['az'] = 'zone-1'
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'zone-1'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    instance = director.instances.first
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)

    instance_name = File.read("#{agent_dir}/instance/name")
    deployment_name = File.read("#{agent_dir}/instance/deployment")
    az_name = File.read("#{agent_dir}/instance/az")
    id = File.read("#{agent_dir}/instance/id")

    expect(instance_name).to eq('fake-name1')
    expect(deployment_name).to eq('simple')
    expect(az_name).to eq('zone-1')
    expect(id).to eq(instance.id)
  end

  context 'password' do
    context 'deployment manifest specifies VM password' do
      context 'director deployment does not set generate_vm_passwords' do
        it 'uses specified VM password' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

          instance = director.instances.first
          agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
          user_password = File.read("#{agent_dir}/bosh/vcap/password")
          root_password = File.read("#{agent_dir}/bosh/root/password")

          expect(user_password).to eq('foobar')
          expect(root_password).to eq('foobar')
        end
      end

      context 'director deployment sets generate_vm_passwords as true' do
        with_reset_sandbox_before_each(generate_vm_passwords: true)
        it 'does not generate a random password and instead uses specified VM password' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

          instance = director.instances.first
          agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
          user_password = File.read("#{agent_dir}/bosh/vcap/password")
          root_password = File.read("#{agent_dir}/bosh/root/password")

          expect(user_password).to eq('foobar')
          expect(root_password).to eq('foobar')
        end
      end
    end

    context 'deployment manifest does not specify VM password' do

      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'].first['env'] = {}
        cloud_config_hash
      end

      context 'director deployment does not set generate_vm_passwords' do
        it 'does not override default VM password' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

          instance = director.instances.first
          agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
          user_password_exists = File.exist?("#{agent_dir}/bosh/vcap/password")
          root_password_exists = File.exist?("#{agent_dir}/bosh/root/password")

          expect(user_password_exists).to be_falsey
          expect(root_password_exists).to be_falsey
        end
      end

      context 'director deployment sets generate_vm_passwords as true' do
        with_reset_sandbox_before_each(generate_vm_passwords: true)
        it 'generates a random unique password for each vm' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          manifest_hash['jobs'].first['instances'] = 2
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

          first_instance = director.instances[0]
          first_agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(first_instance.vm_cid)
          first_user_password = File.read("#{first_agent_dir}/bosh/vcap/password")
          first_root_password = File.read("#{first_agent_dir}/bosh/root/password")

          second_instance = director.instances[1]
          second_agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(second_instance.vm_cid)
          second_user_password = File.read("#{second_agent_dir}/bosh/vcap/password")
          second_root_password = File.read("#{second_agent_dir}/bosh/root/password")

          expect(first_user_password.length).to_not eq(0)
          expect(first_root_password.length).to_not eq(0)

          expect(second_user_password.length).to_not eq(0)
          expect(second_root_password.length).to_not eq(0)

          expect(first_user_password).to_not eq(second_user_password)
          expect(first_root_password).to_not eq(second_root_password)
        end
      end
    end
  end

  context 'when a release job modifies a global property in the ERB script' do
    include Bosh::Spec::CreateReleaseOutputParsers
    before do
      release_filename = Dir.chdir(ClientSandbox.test_release_dir) do
        FileUtils.rm_rf('dev_releases')
        output = bosh_runner.run_in_current_dir('create release --with-tarball')
        parse_release_tarball_path(output)
      end

      minimal_manifest = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.test_release_manifest)

      minimal_manifest["properties"] = {"some_namespace" => {"test_property" => "initial value"}}
      minimal_manifest["instance_groups"] = [{"name" => "test_group",
        "instances" => 1,
        "jobs" => [
          {"name" => "job_that_modifies_properties", "release" => "bosh-release"}
        ],
        'networks' => [{'name' => 'a'}],
        'resource_pool' => 'a'
      }]

      cloud_config = Bosh::Spec::Deployments.simple_cloud_config

      deployment_manifest = yaml_file('minimal', minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)

      target_and_login
      bosh_runner.run("upload release #{release_filename}")
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
    end

    it 'does not modify the property for other release jobs' do
      output, exit_code = bosh_runner.run('deploy', return_exit_code: true)
      expect(output).to include("Deployed 'simple' to")
      expect(exit_code).to eq(0)

      target_vm = director.vm('test_group', '0')

      ctl_script = target_vm.read_job_template('job_that_modifies_properties', 'bin/job_that_modifies_properties_ctl')

      expect(ctl_script).to include('test_property initially was initial value')

      other_script = target_vm.read_job_template('job_that_modifies_properties', 'bin/another_script')

      expect(other_script).to include('test_property initially was initial value')
    end
  end
end
