require_relative '../spec_helper'
require 'fileutils'

describe 'deploy', type: :integration do
  context 'with dry run flag' do
    with_reset_sandbox_before_each

    context 'when there are template errors' do
      it 'prints all template evaluation errors and does not register an event' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'] = [
          {
            'name' => 'foobar',
            'jobs' => ['name' => 'foobar_with_bad_properties'],
            'vm_type' => 'a',
            'instances' => 1,
            'networks' => [{
              'name' => 'a',
            }],
            'properties' => {},
            'stemcell' => 'default'
          }
        ]

        output = deploy_from_scratch(
          manifest_hash: manifest_hash,
          cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config,
          failure_expected: true,
          dry_run: true
        )

        expect(output).to include <<-EOF
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'foobar'. Errors are:
    - Unable to render templates for job 'foobar_with_bad_properties'. Errors are:
      - Error filling in template 'foobar_ctl' (line 8: Can't find property '["test_property"]')
      - Error filling in template 'drain.erb' (line 4: Can't find property '["dynamic_drain_wait1"]')
        EOF

        expect(director.vms.length).to eq(0)
      end
    end

    context 'when there are no errors' do
      it 'returns some encouraging message but does not alter deployment' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, dry_run: true)

        expect(director.vms).to eq ([])
      end
    end
  end

  context 'a very simple deploy' do
    with_reset_sandbox_before_each

    before do
      deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    end

    it 'should contain the worker name in the debug log' do
      output = bosh_runner.run("task --debug 3")

      # sanity test with static expectation
      expect(output).to match(/Starting task: 3$/)

      # we currently run three workers
      expect(output).to match(/Running from worker 'worker_(0|1|2)' on some-name\/some-id \(127\.1\.127\.1\)$/)
    end
  end

  context 'when deploying with multiple cloud configs' do
    with_reset_sandbox_before_each

    let(:first_cloud_config) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['vm_types'] = [{'name'  => 'a', 'cloud_properties' => {'prop-key-a' => 'prop-val-a'}}, Bosh::Spec::NewDeployments.compilation_vm_type]
      yaml_file('first-cloud-config', cloud_config_hash)
    end
    let(:second_cloud_config) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['vm_types'] = [{'name'  => 'b', 'cloud_properties' => {'prop-key-b' => 'prop-val-b'}}]
      cloud_config_hash.delete('compilation')
      cloud_config_hash.delete('networks')
      yaml_file('second-cloud-config', cloud_config_hash)
    end
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group(name: 'second-foobar', vm_type: 'b')
      manifest_hash
    end

    before do
      create_and_upload_test_release
      upload_stemcell
      bosh_runner.run("update-config --name=first-cloud-config cloud #{first_cloud_config.path}")
      bosh_runner.run("update-config --name=second-cloud-config cloud #{second_cloud_config.path}")
    end

    it 'can use configuration from all the uploaded configs' do
      deploy_simple_manifest(manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      first_cloud_config_vms = create_vm_invocations.select { |i| i.inputs['cloud_properties'] == {'prop-key-a' => 'prop-val-a'}}
      second_cloud_config_vms = create_vm_invocations.select { |i| i.inputs['cloud_properties'] == {'prop-key-b' => 'prop-val-b'}}
      expect(first_cloud_config_vms.count).to eq(3)
      expect(second_cloud_config_vms.count).to eq(3)
    end
  end

  context 'when dns is enabled' do
    with_reset_sandbox_before_each

    it 'allows removing deployed jobs and adding new jobs at the same time' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['name'] = 'fake-name1'
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      expect_running_vms_with_names_and_count('fake-name1' => 3)

      manifest_hash['instance_groups'].first['name'] = 'fake-name2'
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('fake-name2' => 3)

      manifest_hash['instance_groups'].first['name'] = 'fake-name1'
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('fake-name1' => 3)
    end

    context 'when stemcell is specified with an OS' do
      it 'deploys with the stemcell with specified OS and version' do
        create_and_upload_test_release

        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
        stemcell_id = current_sandbox.cpi.all_stemcells[0]['id']

        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_v2.tgz')}")

        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['stemcells'].first.delete('name')
        manifest_hash['stemcells'].first['os'] = 'toronto-os'
        manifest_hash['stemcells'].first['version'] = '1'
        manifest_hash['instance_groups'].first['instances'] = 1
        deploy_simple_manifest(manifest_hash: manifest_hash)

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.count).to be > 0

        create_vm_invocations.each do |invocation|
          expect(invocation['inputs']['stemcell_id']).to eq(stemcell_id)
        end

      end
    end

    context 'when stemcell is using latest version' do
      it 'redeploys with latest version of stemcell' do
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['stemcells'].first['version'] = 'latest'
        manifest_hash['instance_groups'].first['instances'] = 1

        create_and_upload_test_release
        upload_cloud_config(cloud_config_hash: cloud_config)

        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
        stemcell_1 = table(bosh_runner.run('stemcells', :json => true)).last
        expect(stemcell_1['version']).to eq('1')

        deploy_simple_manifest(manifest_hash: manifest_hash)
        invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        initial_count = invocations.count
        expect(initial_count).to be > 1
        expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell_1['cid'])

        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_v2.tgz')}")
        stemcell_2 = table(bosh_runner.run('stemcells', :json => true)).first
        expect(stemcell_2['version']).to eq('2')

        deploy_simple_manifest(manifest_hash: manifest_hash)
        invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(invocations.count).to be > initial_count
        expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell_2['cid'])
      end
    end

    it 'deployment fails when starting task fails' do
      deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)
      director.instance('foobar', '0').fail_start_task
      _, exit_code = deploy(failure_expected: true, return_exit_code: true)
      expect(exit_code).to_not eq(0)
    end

    context 'when using legacy deployment configuration' do
      let(:legacy_manifest_hash) do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(Bosh::Spec::Deployments.simple_cloud_config)
        manifest_hash['resource_pools'].find { |i| i['name'] == 'a' }['size'] = 5
        manifest_hash
      end

      before do
        create_and_upload_test_release
        upload_stemcell
      end

      context 'when a cloud config is uploaded' do
        it 'ignores the cloud config and deploys legacy style' do
          cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

          upload_cloud_config(cloud_config_hash: cloud_config_hash)
          output = deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
          expect(output).not_to include('Deployment manifest should not contain cloud config properties')
          expect_running_vms_with_names_and_count('foobar' => 3)
          expect_table('deployments', [
            {
              'name' => Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME,
              'release_s' => 'bosh-release/0+dev.1',
              'stemcell_s' => 'ubuntu-stemcell/1',
              'team_s' => '',
              'cloud_config' => 'none',
            }
          ])
        end
      end

      context 'when deploying v1 after uploaded cloud config and having one stale deployment' do
        let!(:test_release_manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

        it 'ignores cloud config, fails to allocate already taken ips' do
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

          cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
          upload_cloud_config(cloud_config_hash: cloud_config_hash)
          output = deploy_simple_manifest(manifest_hash: test_release_manifest)
          expect(output).not_to include("Ignoring cloud config. Manifest contains 'network' section")

          legacy_manifest = legacy_manifest_hash
          legacy_manifest['name'] = 'simple_2'
          output, exit_code = deploy_simple_manifest(manifest_hash: legacy_manifest, return_exit_code: true, failure_expected: true)
          expect(exit_code).to_not eq(0)
          expect(exit_code).to_not eq(nil)

          expect(output).to match(/IP Address \d+\.\d+\.\d+\.\d+ in network '.*?' is already in use/)
        end
      end

      context 'when no cloud config is uploaded' do
        it 'respects the cloud related configurations in the deployment manifest' do
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

          expect_running_vms_with_names_and_count('foobar' => 3)
          expect_table('deployments', [
            {
              'name' => Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME,
              'release_s' => 'bosh-release/0+dev.1',
              'stemcell_s' => 'ubuntu-stemcell/1',
              'team_s' => '',
              'cloud_config' => 'none',
            }
          ])
        end
      end
    end

    context 'it supports running pre-start scripts' do
      before do
        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        upload_stemcell
      end

      context 'when the pre-start scripts are valid' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_templates_having_prestart_scripts',
                jobs: [
                  {'name' => 'job_1_with_pre_start_script'},
                  {'name' => 'job_2_with_pre_start_script'}
                ],
                instances: 1)]
            })
        end

        before { create_and_upload_test_release }

        it 'runs the pre-start scripts on the agent vm, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
          deploy(manifest_hash: manifest)

          agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id

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
        manifest = Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
            'releases' => [{
              'name' => 'release_with_prestart_script',
              'version' => '1',
            }],
            'instance_groups' => [
              Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_templates_having_prestart_scripts',
                jobs: [
                  {'name' => 'job_1_with_pre_start_script'}
                ],
                instances: 1)]
          })
        bosh_runner.run("upload-release #{spec_asset('pre_start_script_releases/release_with_prestart_script-1.tgz')}")
        deploy(manifest_hash: manifest)

        # re-upload a different release version to make the pre-start scripts run
        manifest['releases'][0]['version'] = '2'
        bosh_runner.run("upload-release #{spec_asset('pre_start_script_releases/release_with_prestart_script-2.tgz')}")
        deploy(manifest_hash: manifest)

        agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id
        job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stderr.log")

        expect(job_1_stdout).to match_output '
        message on stdout of job 1 pre-start script
        template interpolation works in this script: this is pre_start_message_1
        message on stdout of job 1 new version pre-start script
      '

        expect(job_1_stderr).to match_output '
        message on stderr of job 1 pre-start script
        message on stderr of job 1 new version pre-start script
      '
      end

      context 'when the pre-start scripts are corrupted' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'releases' => [{
                'name' => 'release_with_corrupted_pre_start',
                'version' => '1',
              }],
              'instance_groups' => [
                Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'job_with_templates_having_prestart_scripts',
                  jobs: [
                    {'name' => 'job_with_valid_pre_start_script'},
                    {'name' => 'job_with_corrupted_pre_start_script'}
                  ],
                  instances: 1)]
            })
        end

        it 'error out if run_script errors, and redirects stdout/stderr to pre-start.stdout.log/pre-start.stderr.log for each job' do
          bosh_runner.run("upload-release #{spec_asset('pre_start_script_releases/release_with_corrupted_pre_start-1.tgz')}")
          expect {
            deploy(manifest_hash: manifest)
          }.to raise_error(RuntimeError, /result: 1 of 2 pre-start scripts failed. Failed Jobs: job_with_corrupted_pre_start_script. Successful Jobs: job_with_valid_pre_start_script./)

          agent_id = director.instance('job_with_templates_having_prestart_scripts', '0').agent_id

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
        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        upload_stemcell
      end

      context 'when the post-deploy scripts are valid' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_post_deploy_script',
                jobs: [
                  {'name' => 'job_1_with_post_deploy_script'},
                  {'name' => 'job_2_with_post_deploy_script'}
                ],
                instances: 1),
                Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'another_job_with_post_deploy_script',
                  jobs: [
                    {'name' => 'job_1_with_post_deploy_script'},
                    {'name' => 'job_2_with_post_deploy_script'}
                  ],
                  instances: 1)]
            })
        end

        before { create_and_upload_test_release }

        it 'runs the post-deploy scripts on the agent vm, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
          deploy(manifest_hash: manifest)

          agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

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

        it 'does not run post-deploy scripts on stopped vms' do
          deploy(manifest_hash: manifest)

          agent_id_1 = director.instance('job_with_post_deploy_script', '0').agent_id
          agent_id_2 = director.instance('another_job_with_post_deploy_script', '0').agent_id

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_2}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

          stop_job('another_job_with_post_deploy_script/0')

          agent_id_1 = director.instance('job_with_post_deploy_script', '0').agent_id
          agent_id_2 = director.instance('another_job_with_post_deploy_script', '0').agent_id

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_1}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(2)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(2)

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id_2}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        end

        context 'when hm is running', hm: true do
          with_reset_hm_before_each

          it 'runs the post-deploy script when a vm is resurrected' do
            deploy(manifest_hash: manifest)

            agent_id = director.instance('job_with_post_deploy_script', '0').agent_id
            agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
            expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

            resurrected_instance = director.kill_vm_and_wait_for_resurrection(director.instance('job_with_post_deploy_script', '0'))

            agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{resurrected_instance.agent_id}.log")
            expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          end
        end
      end

      context 'when the post-deploy scripts exit with error' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_post_deploy_script',
                jobs: [
                  {'name' => 'job_1_with_post_deploy_script'},
                  {'name' => 'job_3_with_broken_post_deploy_script'}
                ],
                instances: 1)]
            })
        end

        before { create_and_upload_test_release }

        it 'exits with error if post-deploy errors, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
          expect { deploy(manifest_hash: manifest) }.to raise_error(RuntimeError, /result: 1 of 2 post-deploy scripts failed. Failed Jobs: job_3_with_broken_post_deploy_script. Successful Jobs: job_1_with_post_deploy_script./)

          agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

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
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_post_deploy_script',
                jobs: [
                  {'name' => 'job_1_with_post_deploy_script'},
                  {'name' => 'job_2_with_post_deploy_script'}
                ],
                instances: 1),
                Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'job_with_errand',
                  jobs: [
                    {'name' => 'errand1'}
                  ],
                  instances: 1,
                  lifecycle: 'errand')]
            })
        end

        before { create_and_upload_test_release }

        it 'should not run the post deploy script if no changes have been made in deployment' do
          deploy(manifest_hash: manifest)
          agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)

          deploy(manifest_hash: manifest)
          agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
          expect(agent_log.scan("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
          expect(agent_log.scan("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed").size).to eq(1)
        end

        it 'should not run post deploy script on jobs with no vm_cid' do
          deploy(manifest_hash: manifest)
          agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

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
      let(:manifest) do
        Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
            'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'job_with_post_deploy_script',
              jobs: [
                {'name' => 'job_1_with_post_deploy_script'},
                {'name' => 'job_2_with_post_deploy_script'}
              ],
              instances: 1),
              Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'another_job_with_post_deploy_script',
                jobs: [
                  {'name' => 'job_1_with_post_deploy_script'},
                  {'name' => 'job_2_with_post_deploy_script'}
                ],
                instances: 1)]
          })
      end

      before do
        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        upload_stemcell

        create_and_upload_test_release
      end

      it 'runs the post-deploy scripts on the agent vm, and redirects stdout/stderr to post-deploy.stdout.log/post-deploy.stderr.log for each job' do
        deploy(manifest_hash: manifest)

        agent_id = director.instance('job_with_post_deploy_script', '0').agent_id

        agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
        expect(agent_log).to_not include("/jobs/job_1_with_post_deploy_script/bin/post-deploy' script has successfully executed")
        expect(agent_log).to_not include("/jobs/job_2_with_post_deploy_script/bin/post-deploy' script has successfully executed")

        expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")).to be_falsey
        expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stderr.log")).to be_falsey
        expect(File.exists?("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_post_deploy_script/post-deploy.stdout.log")).to be_falsey
      end
    end

    context 'when deployment manifest has local templates properties defined' do
      let(:manifest) do
        Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
            'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'job_with_templates_having_properties',
              jobs: [
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
      end

      before do
        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        upload_stemcell
        create_and_upload_test_release
      end

      it 'these templates should use the properties defined in their scope' do
        deploy(manifest_hash: manifest)
        target_instance = director.instance('job_with_templates_having_properties', '0')
        template_1 = YAML.load(target_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        template_2 = YAML.load(target_instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

        expect(template_1['properties_list']['smurfs_color']).to eq('red')
        expect(template_1['properties_list']['gargamel_color']).to eq('black')

        expect(template_2['properties_list']['smurfs_color']).to eq('yellow')
        expect(template_2['properties_list']['gargamel_color']).to eq('blue')
      end

      it 'should update the job when template properties change' do
        deploy(manifest_hash: manifest)

        manifest = Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
            'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'job_with_templates_having_properties',
              jobs: [
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

        output = deploy(manifest_hash: manifest)
        expect(output).to include('Updating instance job_with_templates_having_properties')
      end

      it 'should not update the job when template properties are the same' do
        deploy(manifest_hash: manifest)
        output = deploy(manifest_hash: manifest)
        expect(output).to_not include('Updating instance job_with_templates_having_properties')
      end


      context 'when the template has local properties defined but missing some of them' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_templates_having_properties',
                jobs: [
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
        end

        it 'should fail even if the properties are defined outside the template scope' do
          output, exit_code = deploy(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

          expect(exit_code).to_not eq(0)
          expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'job_with_templates_having_properties'. Errors are:
    - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
      - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
          EOF
        end
      end

      context 'when multiple templates has local properties' do
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'job_with_templates_having_properties',
                jobs: [
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
        end

        it 'should not cross reference them' do
          deploy(manifest_hash: manifest)
          target_instance = director.instance('job_with_templates_having_properties', '0')
          template_1 = YAML.load(target_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          template_2 = YAML.load(target_instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

          expect(template_1['properties_list']['smurfs_color']).to eq('pink')
          expect(template_1['properties_list']['gargamel_color']).to eq('orange')

          expect(template_2['properties_list']['smurfs_color']).to eq('brown')
          expect(template_2['properties_list']['gargamel_color']).to eq('purple')
        end
      end

      context 'when same template is referenced in multiple deployment jobs' do
        let (:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [
                Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'worker_1',
                  jobs: [
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
                Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'worker_2',
                  jobs: [
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
          deploy(manifest_hash: manifest)

          target_vm_1 = director.instance('worker_1', '0')
          template_1_in_worker_1 = YAML.load(target_vm_1.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          template_2_in_worker_1 = YAML.load(target_vm_1.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

          target_vm_2 = director.instance('worker_2', '0')
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
          manifest['instance_groups'][1]['properties'] = {}

          output, exit_code = deploy(manifest_hash: manifest, return_exit_code: true, failure_expected: true)

          expect(exit_code).to_not eq(0)
          expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'worker_2'. Errors are:
    - Unable to render templates for job 'job_2_with_many_properties'. Errors are:
      - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
          EOF
        end
      end
    end

    it 'supports scaling down and then scaling up' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash['instance_groups'].first['instances'] = 3
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 3)

      manifest_hash['instance_groups'].first['instances'] = 2
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 2)

      manifest_hash['instance_groups'].first['instances'] = 4
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 4)
    end

    it 'supports dynamically sized resource pools' do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 3

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 3)

      # scale down
      manifest_hash['instance_groups'].first['instances'] = 1
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 1)

      # scale up, below original size
      manifest_hash['instance_groups'].first['instances'] = 2
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 2)

      # scale up, above original size
      manifest_hash['instance_groups'].first['instances'] = 4
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('foobar' => 4)
    end

    it 'outputs properly formatted deploy information' do
      # We need to keep this test since the output is not tested and
      # keeps breaking.

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1

      output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      duration_regex = '\\d\\d:\\d\\d:\\d\\d'
      step_duration_regex = '\\(' + duration_regex + '\\)'
      date_regex = '\\d\\d:\\d\\d:\\d\\d'
      sha_regex = '[0-9a-z]+'
      task_regex = '\\d+'
      uuid_regex = '[0-9a-f]{8}-[0-9a-f-]{27}'

      # order for creating missing vms is not guaranteed (running in parallel)
      expect(output).to match(strip_heredoc <<-OUT)
#{date_regex} | Preparing deployment: Preparing deployment (#{duration_regex})
#{date_regex} | Preparing package compilation: Finding packages to compile (#{duration_regex})
#{date_regex} | Compiling packages: foo/0ee95716c58cf7aab3ef7301ff907118552c2dda (#{duration_regex})
#{date_regex} | Compiling packages: bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73 (#{duration_regex})
#{date_regex} | Creating missing vms: foobar/82a2b496-35f7-4c82-8f6a-9f70af106798 (0) (#{duration_regex})
#{date_regex} | Updating job foobar: foobar/82a2b496-35f7-4c82-8f6a-9f70af106798 (0) (canary) (#{duration_regex})
      OUT
    end

    context 'it supports compiled releases' do
      context 'release and stemcell have been uploaded' do
        before do
          bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
          bosh_runner.run("upload-release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
        end

        context 'it uploads the compiled release when there is no corresponding stemcell' do
          it 'should not raise an error' do
            bosh_runner.run('delete-stemcell bosh-aws-xen-hvm-centos-7-go_agent/3001')
            bosh_runner.run('delete-release test_release')
            expect {
              bosh_runner.run("upload-release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
            }.to_not raise_exception
            output = bosh_runner.run('inspect-release test_release/1', json: true)
            puts output.pretty_inspect
            expect(table(output)).to include({
              'package' => 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
              'blobstore_id' => /[a-f0-9\-]{36}/,
              'digest' => '735987b52907d970106f38413825773eec7cc577',
              'compiled_for' => 'centos-7/3001',
            })
            expect(table(output)).to include({
              'package' => 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
              'blobstore_id' => '',
              'digest' => '',
              'compiled_for' => '(source)',
            })
          end
        end

        context 'when older compiled and newer non-compiled (source release) versions of the same release are uploaded' do
          before do
            upload_cloud_config
          end

          context 'and they contain identical packages' do
            let(:manifest) do
              manifest = Bosh::Spec::NewDeployments.test_deployment_manifest_with_job('job_using_pkg_5')
              manifest['stemcells'].first.delete('os')
              manifest['stemcells'].first['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
              manifest['stemcells'].first['version'] = '3001'
              manifest['releases'][0]['version'] = '4'
              manifest
            end

            before { bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-4-same-packages-as-1.tgz')}") }

            it 'does not compile any packages' do
              output = deploy(manifest_hash: manifest)

              expect(output).to_not include('Started compiling packages')
            end
          end

          context 'and they contain one different package' do
            let(:manifest) do
              manifest = Bosh::Spec::NewDeployments.test_deployment_manifest_with_job('job_using_pkg_5')
              manifest['stemcells'].first.delete('os')
              manifest['stemcells'].first['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
              manifest['stemcells'].first['version'] = '3001'
              manifest['releases'][0]['version'] = '3'
              manifest
            end

            before {
              bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')}")
            }

            it 'compiles only the package with the different version and those that depend on it' do
              out = deploy(manifest_hash: manifest)
              expect(out).to include('Compiling packages: pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
              expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

              expect(out).to_not include('Compiling packages: pkg_2/')
              expect(out).to_not include('Compiling packages: pkg_3_depends_on_2/')
              expect(out).to_not include('Compiling packages: pkg_4_depends_on_3/')
            end
          end

          context 'when deploying with a stemcell that does not match the compiled release' do
            before do
              # switch deployment to use "ubuntu-stemcell/1"
              bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
              upload_cloud_config
            end

            it 'fails with an error message saying there is no way to compile for that stemcell' do
              out = deploy(manifest_hash: Bosh::Spec::NewDeployments.test_deployment_manifest_with_job('job_using_pkg_5'), failure_expected: true)
              expect(out).to include('Error:')

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
                bosh_runner.run("upload-release #{spec_asset('compiled_releases/release-test_release_a-1-on-centos-7-stemcell-3001.tgz')}")
              }

              it 'fails with an error message saying there is no way to compile the releases for that stemcell' do
                out = deploy(manifest_hash: Bosh::Spec::NewDeployments.test_deployment_manifest_referencing_multiple_releases, failure_expected: true)
                expect(out).to include('Error:')

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
        let(:manifest) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            {
              'instance_groups' => [
                {
                  'name' => 'job_with_many_packages',
                  'templates' => [
                    {
                      'name' => 'job_with_many_packages'
                    }
                  ],
                  'vm_type' => 'a',
                  'instances' => 1,
                  'networks' => [{'name' => 'a'}],
                  'stemcell' => 'default',
                }
              ]
            }
          )
        end

        it 'exports, deletes deployment & stemcell, uploads compiled, uploads patch-level stemcell, deploys' do
          upload_cloud_config

          bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")

          [
            'jobs/job_with_blocking_compilation',
            'packages/blocking_package',
            'jobs/fails_with_too_much_output',
            'packages/fails_with_too_much_output',
          ].each do |release_path|
            FileUtils.rm_rf(File.join(ClientSandbox.test_release_dir, release_path))
          end

          create_and_upload_test_release(:force => true)

          manifest['stemcells'].first['version'] = 'latest'
          deploy(manifest_hash: manifest)

          bosh_runner.run('export-release -d simple bosh-release/0.1-dev toronto-os/1')

          bosh_runner.run('delete-deployment -d simple')
          bosh_runner.run('delete-release bosh-release')
          bosh_runner.run('delete-stemcell ubuntu-stemcell/1')

          bosh_runner.run("upload-release #{File.join(Bosh::Dev::Sandbox::Workspace.dir, 'client-sandbox', 'bosh_work_dir')}/bosh-release-0.1-dev-toronto-os-1-*.tgz")
          bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_1_1.tgz')}")

          create_call_count = current_sandbox.cpi.invocations_for_method('create_vm').size
          deploy(manifest_hash: manifest)
          expect(current_sandbox.cpi.invocations_for_method('create_vm').size).to eq(create_call_count + 1)
        end
      end
    end

    context 'when the deployment manifest file is large' do
      let(:deployment_manifest) do
        minimal_manifest = Bosh::Common::DeepCopy.copy(Bosh::Spec::NewDeployments.minimal_manifest)
        minimal_manifest['properties'] = {}
        for i in 0..100000
          minimal_manifest['properties']["property#{i}"] = "value#{i}"
        end

        yaml_file('minimal', minimal_manifest)
      end

      before do
        release_filename = spec_asset('test_release.tgz')
        cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)

        bosh_runner.run("upload-release #{release_filename}")
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      end

      it 'deploys successfully' do
        bosh_runner.run("deploy -d minimal #{deployment_manifest.path}")
      end
    end

    context 'when errand jobs are used' do
      let(:manifest) {
        Bosh::Spec::NewDeployments.manifest_with_release.merge({
          'instance_groups' => [
            Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'job_with_post_deploy_script',
              jobs: [
                {'name' => 'job_1_with_post_deploy_script'},
                {'name' => 'job_2_with_post_deploy_script'}
              ],
              instances: 1),
            Bosh::Spec::NewDeployments.simple_errand_instance_group.merge({
              'name' => 'alive-errand',
            }),
            Bosh::Spec::NewDeployments.simple_errand_instance_group.merge({
              'name' => 'dead-errand',
            }),
          ]
        })
      }

      before do
        prepare_for_deploy
        deploy_simple_manifest(manifest_hash: manifest)
      end

      context 'when errand has been run with --keep-alive' do
        it 'immediately updates the errand job' do
          bosh_runner.run('manifest -d simple')

          bosh_runner.run('run-errand -d simple alive-errand --keep-alive')

          job_with_post_deploy_script_instance = director.instance('job_with_post_deploy_script', '0')
          expect(File.exists?(job_with_post_deploy_script_instance.file_path('jobs/foobar/monit'))).to be_falsey

          job_with_errand_instance = director.instance('alive-errand', '0')
          expect(File.exists?(job_with_errand_instance.file_path('jobs/errand1/bin/run'))).to be_truthy
          expect(File.exists?(job_with_errand_instance.file_path('jobs/foobar/monit'))).to be_falsey

          new_manifest = manifest
          new_manifest['instance_groups'][0]['jobs'] << {'name' => 'foobar'}
          new_manifest['instance_groups'][1]['jobs'] << {'name' => 'foobar'}
          new_manifest['instance_groups'][2]['jobs'] << {'name' => 'foobar'}
          deploy_simple_manifest(manifest_hash: new_manifest)

          job_with_post_deploy_script_instance = director.instance('job_with_post_deploy_script', '0')
          expect(File.exists?(job_with_post_deploy_script_instance.file_path('jobs/foobar/monit'))).to be_truthy

          job_with_errand_instance = director.instance('alive-errand', '0')
          expect(File.exists?(job_with_errand_instance.file_path('jobs/foobar/monit'))).to be_truthy
        end
      end
    end

    it 'saves instance name, deployment name, az, and id to the file system on the instance' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['name'] = 'fake-name1'
      manifest_hash['instance_groups'].first['azs'] = ['zone-1']

      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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
      expect(deployment_name).to eq(Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
      expect(az_name).to eq('zone-1')
      expect(id).to eq(instance.id)
    end

    context 'password' do
      context 'deployment manifest specifies VM password' do
        context 'director deployment does not set generate_vm_passwords' do
          it 'uses specified VM password' do
            manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
            manifest_hash['instance_groups'].first['env'] = {'bosh' => {'password' => 'foobar'}}
            deploy_from_scratch(manifest_hash: manifest_hash)

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
            manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
            manifest_hash['instance_groups'].first['env'] = {'bosh' => {'password' => 'foobar'}}
            deploy_from_scratch(manifest_hash: manifest_hash)

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
          Bosh::Spec::NewDeployments.simple_cloud_config
        end

        context 'director deployment sets generate_vm_passwords as true' do
          with_reset_sandbox_before_each(generate_vm_passwords: true)
          it 'generates a random unique password for each vm' do
            manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
            manifest_hash['instance_groups'].first['instances'] = 2
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

      let(:deployment_manifest) do
        minimal_manifest = Bosh::Common::DeepCopy.copy(Bosh::Spec::NewDeployments.manifest_with_release)

        minimal_manifest['properties'] = {'some_namespace' => {'test_property' => 'initial value'}}
        minimal_manifest['instance_groups'] = [{'name' => 'test_group',
          'instances' => 1,
          'jobs' => [
            {'name' => 'job_that_modifies_properties', 'release' => 'bosh-release'}
          ],
          'networks' => [{'name' => 'a'}],
          'vm_type' => 'a',
          'stemcell' => 'default'
        }]

        yaml_file('minimal', minimal_manifest)
      end

      let!(:release_file) { Tempfile.new('release.tgz') }
      after { release_file.delete }

      before do
        Dir.chdir(ClientSandbox.test_release_dir) do
          FileUtils.rm_rf('dev_releases')
          bosh_runner.run_in_current_dir("create-release --tarball=#{release_file.path}")
        end

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)

        bosh_runner.run("upload-release #{release_file.path}")
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      end

      it 'does not modify the property for other templates' do
        deployment_name = Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME
        bosh_runner.run("deploy -d #{deployment_name} #{deployment_manifest.path}")

        target_instance = director.instance('test_group', '0')

        ctl_script = target_instance.read_job_template('job_that_modifies_properties', 'bin/job_that_modifies_properties_ctl')

        expect(ctl_script).to include('test_property initially was initial value')

        other_script = target_instance.read_job_template('job_that_modifies_properties', 'bin/another_script')

        expect(other_script).to include('test_property initially was initial value')
      end
    end
  end

  context 'when dns is disabled' do
    with_reset_sandbox_before_each(dns_enabled: false)

    it 'allows removing deployed jobs and adding new jobs at the same time' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['name'] = 'fake-name1'
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      expect_running_vms_with_names_and_count('fake-name1' => 3)

      manifest_hash['instance_groups'].first['name'] = 'fake-name2'
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('fake-name2' => 3)

      manifest_hash['instance_groups'].first['name'] = 'fake-name1'
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('fake-name1' => 3)
    end
  end
end
