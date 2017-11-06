require_relative '../spec_helper'

describe 'ignore/unignore-instance', type: :integration do
  with_reset_sandbox_before_each

  def safe_include(value, substring, defaults_to = false)
    if value.nil?
      defaults_to
    else
      value.include? substring
    end
  end

  it 'changes the ignore value of vms correctly' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    director.instances.each do |instance|
      expect(instance.ignore).to eq('false')
    end

    initial_instances = director.instances
    instance1 = initial_instances[0]
    instance2 = initial_instances[1]
    instance3 = initial_instances[2]

    bosh_runner.run("ignore #{instance1.job_name}/#{instance1.id}", deployment_name: 'simple')
    bosh_runner.run("ignore #{instance2.job_name}/#{instance2.id}", deployment_name: 'simple')
    expect(director.instance(instance1.job_name, instance1.id).ignore).to eq('true')
    expect(director.instance(instance2.job_name, instance2.id).ignore).to eq('true')
    expect(director.instance(instance3.job_name, instance3.id).ignore).to eq('false')

    bosh_runner.run("unignore #{instance2.job_name}/#{instance2.id}", deployment_name: 'simple')
    expect(director.instance(instance1.job_name, instance1.id).ignore).to eq('true')
    expect(director.instance(instance2.job_name, instance2.id).ignore).to eq('false')
    expect(director.instance(instance3.job_name, instance3.id).ignore).to eq('false')
  end

  it 'fails when deleting deployment that has ignored instances even when using force flag' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    foobar1_instance1 = director.instances.first
    bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

    output, exit_code = bosh_runner.run("delete-deployment", deployment_name: 'simple', failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
    expect(output).to include("You are trying to delete deployment 'simple', which contains ignored instance(s). Operation not allowed.")

    output, exit_code = bosh_runner.run("delete-deployment --force", deployment_name: 'simple', failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
    expect(output).to include("You are trying to delete deployment 'simple', which contains ignored instance(s). Operation not allowed.")
  end

  it 'fails when trying to attach a disk to an ignored instance' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    foobar1_instance1 = director.instances.first
    bosh_runner.run("stop #{foobar1_instance1.job_name}/#{foobar1_instance1.id} --hard", deployment_name: 'simple')

    bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

    output, exit_code = bosh_runner.run("attach-disk #{foobar1_instance1.job_name}/#{foobar1_instance1.id} smurf-disk", deployment_name: 'simple', failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
    expect(output).to include("Error: Instance '#{foobar1_instance1.job_name}/#{foobar1_instance1.id}' in deployment 'simple' is in 'ignore' state. " +
                                  'Attaching disks to ignored instances is not allowed.')
  end

  context 'when there are ignored instances and a deploy happens' do

    context 'when there are pre-start, post-start, and post deploy scripts' do
      with_reset_sandbox_before_each(enable_post_deploy: true)

      it 'does not run them on the ignored vms' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_with_post_start_script'},
                {'name' => 'job_1_with_post_deploy_script'}
            ],
            instances: 2)

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        initial_instances = director.instances
        foobar1_instance1 = initial_instances[0]
        foobar1_instance2 = initial_instances[1]

        agent_id_1 = foobar1_instance1.agent_id
        agent_id_2 = foobar1_instance2.agent_id

        # ==========================================================
        # Pre-Start
        instance1_job_1_pre_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        expect(
            instance1_job_1_pre_start_stdout.scan(/message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1/).count
        ).to eq(1)

        instance2_job_1_pre_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        expect(
            instance2_job_1_pre_start_stdout.scan(/message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1/).count
        ).to eq(1)

        # ==========================================================
        # Post-Start
        instance1_job_1_post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
        expect(
            instance1_job_1_post_start_stdout.scan(/message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message/).count
        ).to eq(1)

        instance2_job_1_post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
        expect(
            instance2_job_1_post_start_stdout.scan(/message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message/).count
        ).to eq(1)

        # ==========================================================
        # Post-Deploy
        instance1_job_1_post_deploy_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(
            instance1_job_1_post_deploy_stdout.scan(/message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1/).count
        ).to eq(1)

        instance2_job_1_post_deploy_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(
            instance2_job_1_post_deploy_stdout.scan(/message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1/).count
        ).to eq(1)

        # ==========================================================
        # ignore
        # ==========================================================
        bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
        bosh_runner.run("restart", deployment_name: 'simple')

        # ==========================================================
        # Pre-Start
        instance1_job_1_pre_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        expect(
            instance1_job_1_pre_start_stdout.scan(/message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1/).count
        ).to eq(1)


        instance2_job_1_pre_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
        expect(
            instance2_job_1_pre_start_stdout.scan(/message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1/).count
        ).to eq(2)

        # ==========================================================
        # Post-Start
        instance1_job_1_post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
        expect(
            instance1_job_1_post_start_stdout.scan(/message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message/).count
        ).to eq(1)

        instance2_job_1_post_start_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_with_post_start_script/post-start.stdout.log")
        expect(
            instance2_job_1_post_start_stdout.scan(/message on stdout of job post-start script\ntemplate interpolation works in this script: this is post_start_message/).count
        ).to eq(2)

        # ==========================================================
        # Post-Deploy
        instance1_job_1_post_deploy_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_1}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(
            instance1_job_1_post_deploy_stdout.scan(/message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1/).count
        ).to eq(1)

        instance2_job_1_post_deploy_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id_2}/data/sys/log/job_1_with_post_deploy_script/post-deploy.stdout.log")
        expect(
            instance2_job_1_post_deploy_stdout.scan(/message on stdout of job 1 post-deploy script\ntemplate interpolation works in this script: this is post_deploy_message_1/).count
        ).to eq(2)
      end
    end

    context 'when the number of instances in an instance group did not change between deployments' do
      it 'leaves ignored instances alone when instance count is 1' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 1})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar3', :instances => 1})

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output.split("\n").select do |e|
          e =~ /Updating instance/
        end.count).to eq(3)

        # ignore first VM
        initial_instances = director.instances
        foobar1_instance1 = initial_instances.find{ |instance| instance.job_name == 'foobar1'}

        bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 1)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar3', :instances => 1})

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output).to_not match(/Updating instance foobar1: foobar1\/#{foobar1_instance1.id}/)

        expect(output).to_not match(/Updating instance foobar1/)
        expect(output).to_not match(/Updating instance foobar2/)
        expect(output).to_not match(/Updating instance foobar3/)
      end


      it 'leaves ignored instances alone when count of the instance groups is larger than 1' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 3})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 3})

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(6)

        # ignore first VM
        initial_instances = director.instances
        instance1 = initial_instances[0]
        instance2 = initial_instances[1]
        instance3 = initial_instances[2]
        bosh_runner.run("ignore #{instance1.job_name}/#{instance1.id}", deployment_name: 'simple')

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 3)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 3})

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output).to_not match(/Updating instance foobar1: foobar1\/#{instance1.id}/)
        expect(output).to match(/Updating instance foobar1: foobar1\/#{instance2.id}/)
        expect(output).to match(/Updating instance foobar1: foobar1\/#{instance3.id}/)
      end
    end

    context 'when the existing instances is less than the desired ones' do

      it 'should handle ignored instances' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 1})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(2)

        # ignore first VM
        initial_instances = director.instances
        foobar1_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}.first
        foobar2_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar2'}.first
        bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

        # redeploy with different foobar1 templates
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
            instances: 2)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output).to_not match(/Updating instance foobar1: foobar1\/#{foobar1_instance1.id}/)
        expect(output).to match(/Creating missing vms/)
        expect(output).to match(/Updating instance foobar1/)


        # ======================================================
        # switch ignored instances

        bosh_runner.run("unignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{foobar2_instance1.job_name}/#{foobar2_instance1.id}", deployment_name: 'simple')

        # Redeploy with different numbers
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [ {'name' => 'job_2_with_pre_start_script'} ],
            instances: 4)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar2',
            jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
            instances: 3)

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output).to match(/Creating missing vms: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)/)
        expect(output).to match(/Creating missing vms: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(3\)/)

        expect(output).to match(/Creating missing vms: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)/)
        expect(output).to match(/Creating missing vms: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)/)

        expect(output).to match(/Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(0\)/)
        expect(output).to match(/Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)/)
        expect(output).to match(/Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)/)
        expect(output).to match(/Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(3\)/)

        expect(output).to match(/Updating instance foobar2: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)/)
        expect(output).to match(/Updating instance foobar2: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)/)

        expect(output).to match(/Updating instance foobar1: foobar1\/#{foobar1_instance1.id}/)
        expect(output).to_not match(/Updating instance foobar1: foobar1\/#{foobar2_instance1.id}/)
      end

    end

    context 'when the existing instances is larger than the desired ones' do

      context 'when the ignored instances is larger than the desired ones' do
        it "should fail to deploy" do
          manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
          cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4})
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

          expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(5)

          # ignore first VM
          initial_instances = director.instances

          foobar1_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[0]
          foobar1_instance2 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[1]
          foobar1_instance3 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[2]

          bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
          bosh_runner.run("ignore #{foobar1_instance2.job_name}/#{foobar1_instance2.id}", deployment_name: 'simple')
          bosh_runner.run("ignore #{foobar1_instance3.job_name}/#{foobar1_instance3.id}", deployment_name: 'simple')

          # redeploy with different foobar1 templates
          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'foobar1',
              jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2
          )
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)

          expect(exit_code).to_not eq(0)
          expect(output).to include("Instance Group 'foobar1' has 3 ignored instance(s). 2 instance(s) of that instance group were requested. Deleting ignored instances is not allowed.")
        end
      end

      context 'when the ignored instances is equal to desired ones' do
        it 'deletes all non-ignored vms and leaves the ignored alone without updating them' do
          manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
          cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4})
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(5)

          initial_instances = director.instances

          foobar1_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[0]
          foobar1_instance2 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[1]
          foobar1_instance3 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[2]
          foobar1_instance4 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[3]

          bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
          bosh_runner.run("ignore #{foobar1_instance2.job_name}/#{foobar1_instance2.id}", deployment_name: 'simple')

          # ===================================================
          # redeploy with different foobar1 templates
          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'foobar1',
              jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2
          )
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          expect(output).to include("Deleting unneeded instances foobar1: foobar1/#{foobar1_instance3.id}")
          expect(output).to include("Deleting unneeded instances foobar1: foobar1/#{foobar1_instance4.id}")

          expect(output).to_not match(/Updating instance/)
          expect(output).to_not match(/Creating missing vms/)

          expect(
              output.split("\n").select { |e|
                /Deleting unneeded instances/ =~ e
              }.count
          ).to eq(2)

          expect(director.instance(foobar1_instance1.job_name, foobar1_instance1.id).ignore).to eq('true')
          expect(director.instance(foobar1_instance1.job_name, foobar1_instance1.id).last_known_state).to eq('running')
          expect(director.instance(foobar1_instance2.job_name, foobar1_instance2.id).ignore).to eq('true')
          expect(director.instance(foobar1_instance2.job_name, foobar1_instance2.id).last_known_state).to eq('running')
        end
      end

      context 'when the ignored instances are fewer than the desired ones' do

        it 'should keep the ignored instances untouched and adjust the number of remaining functional instances' do

          manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
          cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 5})
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

          expect(output.split("\n").select { |e| /Updating instance/ =~ e  }.count).to eq(6)

          foobar1_instances = director.instances.select{ |instance| instance.job_name == 'foobar1'}
          ignored_instance1 = foobar1_instances[0]
          ignored_instance2 = foobar1_instances[1]

          bosh_runner.run("ignore #{ignored_instance1.job_name}/#{ignored_instance1.id}", deployment_name: 'simple')
          bosh_runner.run("ignore #{ignored_instance2.job_name}/#{ignored_instance2.id}", deployment_name: 'simple')

          # ===================================================
          # redeploy with different foobar1 templates
          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'foobar1',
              jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 3
          )
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

          output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

          expect(output.split("\n").select { |e| /Deleting unneeded instances/ =~ e && /foobar1/ =~ e }.count).to eq(2)
          expect(output.split("\n").select { |e| /Deleting unneeded instances/ =~ e }.count).to eq(2)

          expect(output.split("\n").select { |e| /Updating instance foobar1:/ =~ e }.count).to eq(1)
          expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(1)
          expect(output).to_not match(ignored_instance1.id)
          expect(output).to_not match(ignored_instance2.id)

          modified_instances = director.instances

          expect(modified_instances.count).to eq(4)

          expect(modified_instances.select{ |instance| instance.ignore == 'true' }.count).to eq(2)
          expect(modified_instances.select{ |instance| instance.ignore == 'true' && instance.job_name == 'foobar1' }.count).to eq(2)
          expect(modified_instances.select{ |instance| instance.job_name == 'foobar1' }.count).to eq(3)
          expect(modified_instances.select{ |instance| instance.job_name == 'foobar2' }.count).to eq(1)
          expect(modified_instances.select{ |instance| instance.id == ignored_instance1.id }.count).to eq(1)
          expect(modified_instances.select{ |instance| instance.id == ignored_instance2.id }.count).to eq(1)
        end
      end
    end

    context 'when --recreate flag is passed' do
      it 'should recreate needed vms but leave the ignored ones alone' do

        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 3})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 3})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        # ignore first VM
        initial_instances = director.instances
        foobar1_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[0]
        foobar1_instance2 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[1]
        foobar1_instance3 = initial_instances.select{ |instance| instance.job_name == 'foobar1'}[2]

        foobar2_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar2'}[0]
        foobar2_instance2 = initial_instances.select{ |instance| instance.job_name == 'foobar2'}[1]
        foobar2_instance3 = initial_instances.select{ |instance| instance.job_name == 'foobar2'}[2]

        bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
            name: 'foobar1',
            jobs: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 3)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 3})

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, recreate: true)

        modified_instances = director.instances

        expect(output).to_not match("Updating instance foobar1: foobar1/#{foobar1_instance1.id}")

        expect(
            output.split("\n").select { |e|
              /Updating instance/ =~ e && /foobar1/ =~ e
            }.count
        ).to eq(2)

        expect(
            modified_instances.none? do |instance|
              instance.agent_id == foobar1_instance2.agent_id ||
              instance.agent_id == foobar1_instance3.agent_id ||
              instance.agent_id == foobar2_instance1.agent_id ||
              instance.agent_id == foobar2_instance2.agent_id ||
              instance.agent_id == foobar2_instance3.agent_id
            end
        ).to eq(true)

        expect(
            modified_instances.select { |instance|
              instance.agent_id == foobar1_instance1.agent_id
            }.count
        ).to eq(1)
      end
    end

    context 'when an attempt is made to delete an instance group from deployment' do
      it 'fails if the instance group contains ignored vms' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 2})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        initial_instances = director.instances
        foobar1_instance1 = initial_instances.select{ |instance| instance.job_name == 'foobar1' && instance.index == '0'}.first
        bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 2})

        output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)

        expect(exit_code).to_not eq(0)
        expect(output).to include("You are trying to delete instance group 'foobar1', which contains ignored instance(s). Operation not allowed.")
      end
    end

    context 'when an ignored VM has an unresponsive agent' do
      context 'when using v1 manifest' do
        it 'should timeout and fail' do
          manifest_hash = Bosh::Spec::Deployments.legacy_manifest

          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 2})

          deploy_from_scratch(manifest_hash: manifest_hash, legacy: true)

          initial_instances = director.instances
          foobar1_instance1 = initial_instances[0]
          foobar1_instance2 = initial_instances[1]
          bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

          foobar1_instance1.kill_agent

          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
              name: 'foobar1',
              templates: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2)

          output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true, legacy: true)
          expect(exit_code).to_not eq(0)
          expect(output).to include("Timed out sending 'get_state'")

          modified_instances = director.instances
          modified_foobar1_instance1 = modified_instances.select{|i| i.id == foobar1_instance1.id}.first
          modified_foobar1_instance2 = modified_instances.select{|i| i.id == foobar1_instance2.id}.first

          expect(modified_foobar1_instance1.last_known_state).to eq('unresponsive agent')
          expect(modified_foobar1_instance2.last_known_state).to eq('running')
        end
      end

      context 'when using v2 manifest' do
        it 'should not contact the VM and deploys successfully' do
          manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
          cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})

          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

          initial_instances = director.instances
          foobar1_instance1 = initial_instances[0]
          foobar1_instance2 = initial_instances[1]
          bosh_runner.run("ignore #{foobar1_instance1.job_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

          foobar1_instance1.kill_agent

          manifest_hash['instance_groups'].clear
          manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'foobar1',
              jobs: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2)

          output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          expect(output).to include("Warning: You have ignored instances. They will not be changed.")
          expect(output).to_not include("Updating instance foobar1: foobar1/#{foobar1_instance1.id} (#{foobar1_instance1.index})")
          expect(output).to include("Updating instance foobar1: foobar1/#{foobar1_instance2.id} (#{foobar1_instance2.index})")

          modified_instances = director.instances
          modified_foobar1_instance1 = modified_instances.select{|i| i.id == foobar1_instance1.id}.first
          modified_foobar1_instance2 = modified_instances.select{|i| i.id == foobar1_instance2.id}.first

          expect(modified_foobar1_instance1.last_known_state).to eq('unresponsive agent')
          expect(modified_foobar1_instance2.last_known_state).to eq('running')
        end
      end
    end
  end

  context 'when starting/stopping/restarting/recreating instances' do

    context 'when not specifying an instance group name' do
      it 'should change the state of all instances except the ignored ones' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 3})
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 1})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        def findInstanceByIndexAndName(instances, index, name)
          instances.find  do |instance|
            instance.index == index && instance.job_name == name
          end
        end

        instances_first_state = director.instances

        ignored_instance = findInstanceByIndexAndName(instances_first_state, '0', 'foobar1')
        foobar1_instance_2 = findInstanceByIndexAndName(instances_first_state, '1', 'foobar1')
        foobar1_instance_3 = findInstanceByIndexAndName(instances_first_state, '2', 'foobar1')
        foobar2_instance_1 = findInstanceByIndexAndName(instances_first_state, '0', 'foobar2')

        bosh_runner.run("ignore #{ignored_instance.job_name}/#{ignored_instance.id}", deployment_name: 'simple')

        # ===========================================
        start_output = bosh_runner.run("start", deployment_name: 'simple')
        expect(start_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(start_output).to_not include('Updating instance')

        # ===========================================
        stop_output = bosh_runner.run("stop", deployment_name: 'simple')
        expect(stop_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(stop_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(stop_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(stop_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(stop_output).to match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_stop = director.instances
        expect(findInstanceByIndexAndName(instances_after_stop, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_stop, '1', 'foobar1').last_known_state).to eq('stopped')
        expect(findInstanceByIndexAndName(instances_after_stop, '2', 'foobar1').last_known_state).to eq('stopped')
        expect(findInstanceByIndexAndName(instances_after_stop, '0', 'foobar2').last_known_state).to eq('stopped')


        # ===========================================
        restart_output = bosh_runner.run("restart", deployment_name: 'simple')
        expect(restart_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(restart_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(restart_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(restart_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(restart_output).to match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_restart = director.instances
        expect(findInstanceByIndexAndName(instances_after_restart, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '1', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '2', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '0', 'foobar2').last_known_state).to eq('running')


        # ===========================================
        recreate_output = bosh_runner.run("recreate", deployment_name: 'simple')
        expect(recreate_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(recreate_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(recreate_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(recreate_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(recreate_output).to match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_recreate = director.instances
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '1', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '2', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar2').last_known_state).to eq('running')

        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar1').agent_id).to eq(ignored_instance.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '1', 'foobar1').agent_id).to_not eq(foobar1_instance_2.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '2', 'foobar1').agent_id).to_not eq(foobar1_instance_3.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar2').agent_id).to_not eq(foobar2_instance_1.agent_id)

        # ========================================================================================
        # Targeting an instance group
        # ========================================================================================

        stop_output = bosh_runner.run("stop foobar1", deployment_name: 'simple')
        expect(stop_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(stop_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(stop_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(stop_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(stop_output).to_not match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_stop = director.instances
        expect(findInstanceByIndexAndName(instances_after_stop, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_stop, '1', 'foobar1').last_known_state).to eq('stopped')
        expect(findInstanceByIndexAndName(instances_after_stop, '2', 'foobar1').last_known_state).to eq('stopped')
        expect(findInstanceByIndexAndName(instances_after_stop, '0', 'foobar2').last_known_state).to eq('running')

        # ===========================================
        start_output = bosh_runner.run("start foobar1", deployment_name: 'simple')
        expect(start_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(start_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(start_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(start_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(start_output).to_not match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_start = director.instances
        expect(findInstanceByIndexAndName(instances_after_start, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_start, '1', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_start, '2', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_start, '0', 'foobar2').last_known_state).to eq('running')

        # ===========================================
        restart_output = bosh_runner.run("restart foobar1", deployment_name: 'simple')
        expect(restart_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(restart_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(restart_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(restart_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(restart_output).to_not match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_restart = director.instances
        foobar1_instance_2 = instances_after_restart[1]
        foobar1_instance_3 = instances_after_restart[2]
        foobar2_instance_1 = instances_after_restart[3]

        expect(findInstanceByIndexAndName(instances_after_restart, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '1', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '2', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_restart, '0', 'foobar2').last_known_state).to eq('running')

        # ===========================================
        recreate_output = bosh_runner.run("recreate foobar1", deployment_name: 'simple')
        expect(recreate_output).to include('Warning: You have ignored instances. They will not be changed.')
        expect(recreate_output).to_not match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)/)
        expect(recreate_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)/)
        expect(recreate_output).to match(/Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)/)
        expect(recreate_output).to_not match(/Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)/)

        instances_after_recreate = director.instances
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '1', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '2', 'foobar1').last_known_state).to eq('running')
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar2').last_known_state).to eq('running')

        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar1').agent_id).to eq(ignored_instance.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '1', 'foobar1').agent_id).to_not eq(foobar1_instance_2.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '2', 'foobar1').agent_id).to_not eq(foobar1_instance_3.agent_id)
        expect(findInstanceByIndexAndName(instances_after_recreate, '0', 'foobar2').agent_id).to eq(foobar2_instance_1.agent_id)

        # ========================================================================================
        # Targeting a specific ignored instance
        # ========================================================================================
        stop_output, stop_exit_code = bosh_runner.run("stop #{ignored_instance.job_name}/#{ignored_instance.id}", failure_expected: true, return_exit_code: true, deployment_name: 'simple')
        expect(stop_output).to include("You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. This operation is not allowed. You need to unignore it first.")
        expect(stop_exit_code).to_not eq(0)

        start_output, start_exit_code = bosh_runner.run("start #{ignored_instance.job_name}/#{ignored_instance.id}", failure_expected: true, return_exit_code: true, deployment_name: 'simple')
        expect(start_output).to include("You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. This operation is not allowed. You need to unignore it first.")
        expect(start_exit_code).to_not eq(0)

        restart_output, restart_exit_code = bosh_runner.run("restart #{ignored_instance.job_name}/#{ignored_instance.id}", failure_expected: true, return_exit_code: true, deployment_name: 'simple')
        expect(restart_output).to include("You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. This operation is not allowed. You need to unignore it first.")
        expect(restart_exit_code).to_not eq(0)

        recreate_output, recreate_exit_code = bosh_runner.run("recreate #{ignored_instance.job_name}/#{ignored_instance.id}", failure_expected: true, return_exit_code: true, deployment_name: 'simple')
        expect(recreate_output).to include("You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. This operation is not allowed. You need to unignore it first.")
        expect(recreate_exit_code).to_not eq(0)

      end
    end
  end

  context 'when HM notifies director to scan & fix an ignored VM', hm: true do
    with_reset_hm_before_each

    it 'should not scan & fix the ignored VM' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})
      manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 2})

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      orig_instances = director.instances

      ignored_instance =        orig_instances.select{|instance| instance.job_name == 'foobar1' && instance.index == '0'}.first
      foobar1_instance_2_orig = orig_instances.select{|instance| instance.job_name == 'foobar1' && instance.index == '1'}.first
      foobar2_instance_1_orig = orig_instances.select{|instance| instance.job_name == 'foobar2' && instance.index == '0'}.first
      foobar2_instance_2_orig = orig_instances.select{|instance| instance.job_name == 'foobar2' && instance.index == '1'}.first

      bosh_runner.run("ignore #{ignored_instance.job_name}/#{ignored_instance.id}", deployment_name: 'simple')

      ignored_instance.kill_agent
      foobar2_instance_1_orig.kill_agent

      director.wait_for_vm('foobar2', '0', 300)

      new_instances = director.instances

      ignored_instance_new =   new_instances.select{|instance| instance.job_name == 'foobar1' && instance.index == '0'}.first
      foobar1_instance_2_new = new_instances.select{|instance| instance.job_name == 'foobar1' && instance.index == '1'}.first
      foobar2_instance_1_new = new_instances.select{|instance| instance.job_name == 'foobar2' && instance.index == '0'}.first
      foobar2_instance_2_new = new_instances.select{|instance| instance.job_name == 'foobar2' && instance.index == '1'}.first

      expect(ignored_instance_new.vm_cid).to       eq(ignored_instance.vm_cid)
      expect(foobar1_instance_2_new.vm_cid).to     eq(foobar1_instance_2_orig.vm_cid)
      expect(foobar2_instance_1_new.vm_cid).to_not eq(foobar2_instance_1_orig.vm_cid)
      expect(foobar2_instance_2_new.vm_cid).to     eq(foobar2_instance_2_orig.vm_cid)

      expect(ignored_instance_new.last_known_state).to eq('unresponsive agent')
    end
  end

  context 'when ignoring all of the instances in a zone' do
    context 'when not using static ips' do
      it 'does not rebalance the ignored vms, and it selects a new bootstrap node from ignored instances if needed, and it errors if removing an az containing ignored vms.' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1', 'my-az2']})

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config['azs'] = [
            {
                'name' => 'my-az1'
            },
            {
                'name' => 'my-az2'
            }
        ]
        cloud_config['compilation']['az'] = 'my-az1'

        cloud_config['networks'].first['subnets'] = [
            {
                'range' => '192.168.1.0/24',
                'gateway' => '192.168.1.1',
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az1'
            },
            {
                'range' => '192.168.2.0/24',
                'gateway' => '192.168.2.1',
                'dns' => ['192.168.2.1', '192.168.2.2'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az2'
            }
        ]

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        orig_instances = director.instances

        expect(orig_instances.count).to eq(4)
        p orig_instances
        expect(orig_instances.select{|i| i.availability_zone == 'my-az1'}.count).to eq(2)
        expect(orig_instances.select{|i| i.availability_zone == 'my-az2'}.count).to eq(2)
        expect(orig_instances.select(&:bootstrap).count).to eq(1)

        az2_instances = orig_instances.select{|i| i.availability_zone == 'my-az2'}
        bosh_runner.run("ignore #{az2_instances[0].job_name}/#{az2_instances[0].id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{az2_instances[1].job_name}/#{az2_instances[1].id}", deployment_name: 'simple')

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1', 'my-az2']})
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        new_state_instances = director.instances

        expect(new_state_instances.count).to eq(2)
        expect(new_state_instances.select{|i| i.availability_zone == 'my-az1'}.count).to eq(0)
        expect(new_state_instances.select{|i| i.availability_zone == 'my-az2'}.count).to eq(2)
        expect(new_state_instances.select{|i| i.id == az2_instances[0].id}.count).to eq(1)
        expect(new_state_instances.select{|i| i.id == az2_instances[1].id}.count).to eq(1)
        expect(new_state_instances.select(&:bootstrap).count).to eq(1)

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("Instance Group 'foobar1' no longer contains AZs [\"my-az2\"] where ignored instance(s) exist.")

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1', 'my-az2']})
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1']})
        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("Instance Group 'foobar1' no longer contains AZs [\"my-az2\"] where ignored instance(s) exist.")
      end
    end

    context 'when using static IPs' do
      it 'balances the vms correctly, and it errors if removing an az containing ignored vms, and it errors if removing static IP assigned to an ignored VM' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1', 'my-az2']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.2.10', '192.168.2.11']}]

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config['azs'] = [
            {
                'name' => 'my-az1'
            },
            {
                'name' => 'my-az2'
            }
        ]
        cloud_config['compilation']['az'] = 'my-az1'

        cloud_config['networks'].first['subnets'] = [
            {
                'range' => '192.168.1.0/24',
                'gateway' => '192.168.1.1',
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'static' => ['192.168.1.10-192.168.1.20'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az1'
            },
            {
                'range' => '192.168.2.0/24',
                'gateway' => '192.168.2.1',
                'dns' => ['192.168.2.1', '192.168.2.2'],
                'static' => ['192.168.2.10-192.168.2.20'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az2'
            }
        ]

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        orig_instances = director.instances
        az1_instances = orig_instances.select{|i| i.availability_zone == 'my-az1'}
        az2_instances = orig_instances.select{|i| i.availability_zone == 'my-az2'}

        expect(orig_instances.count).to eq(4)
        expect(az1_instances.count).to eq(2)
        expect(az2_instances.count).to eq(2)
        expect(orig_instances.select(&:bootstrap).count).to eq(1)

        # =======================================================
        # ignore az2 vms
        bosh_runner.run("ignore #{az2_instances[0].job_name}/#{az2_instances[0].id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{az2_instances[1].job_name}/#{az2_instances[1].id}", deployment_name: 'simple')

        # =======================================================
        # remove IPs used by non-ignored vms, should be good
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1', 'my-az2']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.2.10', '192.168.2.11']}]

        output_2 = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        expect(output_2).to_not include('Updating instance')
        expect(output_2).to include("Deleting unneeded instances foobar1: foobar1/#{az1_instances[0].id} (#{az1_instances[0].index})")
        expect(output_2).to include("Deleting unneeded instances foobar1: foobar1/#{az1_instances[1].id} (#{az1_instances[1].index})")

        instances_state_2 = director.instances
        expect(instances_state_2.count).to eq(2)
        expect(instances_state_2.select{|i| i.availability_zone == 'my-az1'}.count).to eq(0)
        expect(instances_state_2.select{|i| i.availability_zone == 'my-az2'}.count).to eq(2)
        expect(instances_state_2.select(&:bootstrap).count).to eq(1)

        # =======================================================
        # remove an ignored vm static IP, should error
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 1, :azs => ['my-az1', 'my-az2']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.2.10']}]

        output_3, exit_code_3 = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code_3).to_not eq(0)
        expect(output_3).to include("In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. This operation is not allowed.")

        # =======================================================
        # remove an az that has ignored VMs, should error
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1', 'my-az2']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.2.10', '192.168.2.11']}]
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 4, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']}]

        output_4, exit_code_4 = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code_4).to_not eq(0)
        expect(output_4).to include("In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. This operation is not allowed.")
      end
    end
  end

  context 'when changing networks configuration for instance groups containing ignored VMs' do
    context 'when not using static ips' do
      it 'fails when adding/removing networks from instance groups with ignored VMs' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config['azs'] = [{'name' => 'my-az1'}]
        cloud_config['compilation']['az'] = 'my-az1'

        cloud_config['networks'].first['subnets'] = [
            {
                'range' => '192.168.1.0/24',
                'gateway' => '192.168.1.1',
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az1'
            }
        ]

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        orig_instances = director.instances
        expect(orig_instances.count).to eq(2)

        bosh_runner.run("ignore #{orig_instances[0].job_name}/#{orig_instances[0].id}", deployment_name: 'simple')

        # =================================================
        # add new network to the instance group that has ignored VM, should fail
        cloud_config['networks'] << {
            'name' => 'b',
            'subnets' => [
                {
                    'range' => '192.168.1.0/24',
                    'gateway' => '192.168.1.1',
                    'dns' => ['192.168.1.1', '192.168.1.2'],
                    'reserved' => [],
                    'cloud_properties' => {},
                    'az' => 'my-az1'
                },
            ],
        }

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'default' => ['dns', 'gateway']}]
        manifest_hash['instance_groups'].first['networks'] << { 'name' => 'b'}

        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. This operation is not allowed.")

        # =================================================
        # remove a network from the instance group that has ignored VM, should fail
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'b', 'default' => ['dns', 'gateway']}]

        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. This operation is not allowed.")
      end
    end

    context 'when using static IPs' do
      it 'does not re-assign static IPs for ignored VM, and fails when adding/removing static networks from instance groups with ignored VMs' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.11']}]

        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
        cloud_config['azs'] = [
            {
                'name' => 'my-az1'
            },
            {
                'name' => 'my-az2'
            }
        ]
        cloud_config['compilation']['az'] = 'my-az1'

        cloud_config['networks'].first['subnets'] = [
            {
                'range' => '192.168.1.0/24',
                'gateway' => '192.168.1.1',
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'static' => ['192.168.1.10-192.168.1.20'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az1'
            },
            {
                'range' => '192.168.2.0/24',
                'gateway' => '192.168.2.1',
                'dns' => ['192.168.2.1', '192.168.2.2'],
                'static' => ['192.168.2.10-192.168.2.20'],
                'reserved' => [],
                'cloud_properties' => {},
                'az' => 'my-az2'
            }
        ]

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        orig_instances = director.instances
        bosh_runner.run("ignore #{orig_instances[0].job_name}/#{orig_instances[0].id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{orig_instances[1].job_name}/#{orig_instances[1].id}", deployment_name: 'simple')

        # =================================================
        # switch a static IP address used by an ignored VM, should fail
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.12']}]

        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. This operation is not allowed.")

        # =================================================
        # add new network to the instance group that has ignored VM, should fail
        cloud_config['networks'] << {
            'name' => 'b',
            'subnets' => [
                {
                    'range' => '192.168.1.0/24',
                    'gateway' => '192.168.1.1',
                    'dns' => ['192.168.1.1', '192.168.1.2'],
                    'static' => ['192.168.1.10-192.168.1.20'],
                    'reserved' => [],
                    'cloud_properties' => {},
                    'az' => 'my-az1'
                },
            ],
        }

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a',  'static_ips' => ['192.168.1.10', '192.168.1.11'], 'default' => ['dns', 'gateway']}]
        manifest_hash['instance_groups'].first['networks'] << { 'name' => 'b'}

        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. This operation is not allowed.")

        # =================================================
        # remove a network from the instance group that has ignored VM, should fail
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2, :azs => ['my-az1']})
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'b', 'static_ips' => ['192.168.1.10', '192.168.1.11'], 'default' => ['dns', 'gateway']}]

        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. This operation is not allowed.")
      end
    end
  end
end
