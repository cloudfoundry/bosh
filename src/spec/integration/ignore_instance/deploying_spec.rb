require 'spec_helper'

describe 'deploying with ignored instances', type: :integration do
  with_reset_sandbox_before_each

  context 'when there are pre-start, post-start, and post deploy scripts' do
    with_reset_sandbox_before_each

    it 'does not run them on the ignored vms' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [
          { 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' },
          { 'name' => 'job_with_post_start_script', 'release' => 'bosh-release' },
          { 'name' => 'job_1_with_post_deploy_script', 'release' => 'bosh-release' },
        ],
        instances: 2,
      )

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      initial_instances = director.instances
      foobar1_instance1 = initial_instances[0]
      foobar1_instance2 = initial_instances[1]

      agent_id1 = foobar1_instance1.agent_id
      agent_id2 = foobar1_instance2.agent_id

      # ==========================================================
      # Pre-Start
      agent1_logs = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id1}/data/sys/log/"
      agent2_logs = "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id2}/data/sys/log/"
      pre_start_regex = Regexp.new(<<~REGEXP.strip)
        message on stdout of job 1 pre-start script
        template interpolation works in this script: this is pre_start_message_1
        REGEXP

      instance1_job_1_pre_start_stdout = File.read(File.join(agent1_logs, 'job_1_with_pre_start_script/pre-start.stdout.log'))
      expect(instance1_job_1_pre_start_stdout.scan(pre_start_regex).count).to eq(1)

      instance2_job_1_pre_start_stdout = File.read(File.join(agent2_logs, 'job_1_with_pre_start_script/pre-start.stdout.log'))
      expect(instance2_job_1_pre_start_stdout.scan(pre_start_regex).count).to eq(1)

      # ==========================================================
      # Post-Start
      post_start_regex = Regexp.new(<<~REGEXP.strip)
        message on stdout of job post-start script
        template interpolation works in this script: this is post_start_message
        REGEXP

      instance1_job_1_post_start_stdout = File.read(File.join(agent1_logs, 'job_with_post_start_script/post-start.stdout.log'))
      expect(instance1_job_1_post_start_stdout.scan(post_start_regex).count).to eq(1)

      instance2_job_1_post_start_stdout = File.read(File.join(agent2_logs, 'job_with_post_start_script/post-start.stdout.log'))
      expect(instance2_job_1_post_start_stdout.scan(post_start_regex).count).to eq(1)

      # ==========================================================
      # Post-Deploy
      post_deploy_regex = Regexp.new(<<~REGEXP.strip)
        message on stdout of job 1 post-deploy script
        template interpolation works in this script: this is post_deploy_message_1
        REGEXP

      instance1_job_1_post_deploy_stdout = File.read(
        File.join(agent1_logs, 'job_1_with_post_deploy_script/post-deploy.stdout.log'),
      )
      expect(instance1_job_1_post_deploy_stdout.scan(post_deploy_regex).count).to eq(1)

      instance2_job_1_post_deploy_stdout = File.read(
        File.join(agent2_logs, 'job_1_with_post_deploy_script/post-deploy.stdout.log'),
      )
      expect(instance2_job_1_post_deploy_stdout.scan(post_deploy_regex).count).to eq(1)

      # ==========================================================
      # ignore
      # ==========================================================
      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
      bosh_runner.run('restart', deployment_name: 'simple')

      # ==========================================================
      # Pre-Start
      instance1_job_1_pre_start_stdout = File.read(File.join(agent1_logs, 'job_1_with_pre_start_script/pre-start.stdout.log'))
      expect(instance1_job_1_pre_start_stdout.scan(pre_start_regex).count).to eq(1)

      instance2_job_1_pre_start_stdout = File.read(File.join(agent2_logs, 'job_1_with_pre_start_script/pre-start.stdout.log'))
      expect(instance2_job_1_pre_start_stdout.scan(pre_start_regex).count).to eq(2)

      # ==========================================================
      # Post-Start
      instance1_job_1_post_start_stdout = File.read(File.join(agent1_logs, 'job_with_post_start_script/post-start.stdout.log'))
      expect(instance1_job_1_post_start_stdout.scan(post_start_regex).count).to eq(1)

      instance2_job_1_post_start_stdout = File.read(File.join(agent2_logs, 'job_with_post_start_script/post-start.stdout.log'))
      expect(instance2_job_1_post_start_stdout.scan(post_start_regex).count).to eq(2)

      # ==========================================================
      # Post-Deploy
      instance1_job_1_post_deploy_stdout = File.read(
        File.join(agent1_logs, 'job_1_with_post_deploy_script/post-deploy.stdout.log'),
      )
      expect(instance1_job_1_post_deploy_stdout.scan(post_deploy_regex).count).to eq(1)

      instance2_job_1_post_deploy_stdout = File.read(
        File.join(agent2_logs, 'job_1_with_post_deploy_script/post-deploy.stdout.log'),
      )
      expect(instance2_job_1_post_deploy_stdout.scan(post_deploy_regex).count).to eq(2)
    end
  end

  context 'when the number of instances in an instance group did not change between deployments' do
    it 'leaves ignored instances alone when instance count is 1' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 1)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar3', instances: 1)

      output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output.split("\n").select do |e|
        e =~ /Updating instance/
      end.count).to eq(3)

      # ignore first VM
      initial_instances = director.instances
      foobar1_instance1 = initial_instances.find { |instance| instance.instance_group_name == 'foobar1' }

      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [
          { 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' },
          { 'name' => 'job_2_with_pre_start_script', 'release' => 'bosh-release' },
        ],
        instances: 1,
      )
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar3', instances: 1)

      output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output).to_not match(%r{Updating instance foobar1: foobar1\/#{foobar1_instance1.id}})

      expect(output).to_not match(/Updating instance foobar1/)
      expect(output).to_not match(/Updating instance foobar2/)
      expect(output).to_not match(/Updating instance foobar3/)
    end

    it 'leaves ignored instances alone when count of the instance groups is larger than 1' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 3)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 3)

      output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(6)

      # ignore first VM
      initial_instances = director.instances
      instance1 = initial_instances[0]
      instance2 = initial_instances[1]
      instance3 = initial_instances[2]
      bosh_runner.run("ignore #{instance1.instance_group_name}/#{instance1.id}", deployment_name: 'simple')

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [
          { 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' },
          { 'name' => 'job_2_with_pre_start_script', 'release' => 'bosh-release' },
        ],
        instances: 3,
      )
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 3)

      output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output).to_not match(%r{Updating instance foobar1: foobar1/#{instance1.id}})
      expect(output).to match(%r{Updating instance foobar1: foobar1/#{instance2.id}})
      expect(output).to match(%r{Updating instance foobar1: foobar1/#{instance3.id}})
    end

    context 'when the instances have persistent disks' do
      let(:cloud_config) do
        SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(azs: %w[z1 z2])
        manifest['instance_groups'][0]['persistent_disk'] = 1024
        manifest
      end

      it 'does not delete an unexpected instance' do
        output = deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(3)

        # ignore first VM
        initial_instances = director.instances
        instance1 = initial_instances[0]
        instance2 = initial_instances[1]
        instance3 = initial_instances[2]
        bosh_runner.run("ignore #{instance1.instance_group_name}/#{instance1.id}", deployment_name: 'simple')

        manifest['instance_groups'][0]['jobs'][0]['properties'] = { 'test_property' => 'new-value' }

        output = deploy_simple_manifest(manifest_hash: manifest, cloud_config_hash: cloud_config)

        expect(output).to_not match(%r{Updating instance foobar: foobar/#{instance1.id}})
        expect(output).to match(%r{Updating instance foobar: foobar/#{instance2.id}})
        expect(output).to match(%r{Updating instance foobar: foobar/#{instance3.id}})
      end
    end
  end

  context 'when the existing instances is less than the desired ones' do
    it 'should handle ignored instances' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 1)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

      output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(2)

      # ignore first VM
      initial_instances = director.instances
      foobar1_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }.first
      foobar2_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar2' }.first
      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      # redeploy with different foobar1 templates
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [{ 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' }],
        instances: 2,
      )
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

      output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output).to_not match(%r{Updating instance foobar1: foobar1\/#{foobar1_instance1.id}})
      expect(output).to match(/Creating missing vms/)
      expect(output).to match(/Updating instance foobar1/)

      # ======================================================
      # switch ignored instances

      bosh_runner.run("unignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
      bosh_runner.run("ignore #{foobar2_instance1.instance_group_name}/#{foobar2_instance1.id}", deployment_name: 'simple')

      # Redeploy with different numbers
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [{ 'name' => 'job_2_with_pre_start_script', 'release' => 'bosh-release' }],
        instances: 4,
      )
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar2',
        jobs: [{ 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' }],
        instances: 3,
      )

      output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      expect(output).to match(
        %r{Creating missing vms: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)},
      )
      expect(output).to match(
        %r{Creating missing vms: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(3\)},
      )

      expect(output).to match(
        %r{Creating missing vms: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)},
      )
      expect(output).to match(
        %r{Creating missing vms: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)},
      )

      expect(output).to match(
        %r{Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(0\)},
      )
      expect(output).to match(
        %r{Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)},
      )
      expect(output).to match(
        %r{Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)},
      )
      expect(output).to match(
        %r{Updating instance foobar1: foobar1\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(3\)},
      )

      expect(output).to match(
        %r{Updating instance foobar2: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(1\)},
      )
      expect(output).to match(
        %r{Updating instance foobar2: foobar2\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f-]{12} \(2\)},
      )

      expect(output).to match(%r{Updating instance foobar1: foobar1\/#{foobar1_instance1.id}})
      expect(output).to_not match(%r{Updating instance foobar1: foobar1\/#{foobar2_instance1.id}})
    end
  end

  context 'when the existing instances is larger than the desired ones' do
    context 'when the ignored instances is larger than the desired ones' do
      it 'should fail to deploy' do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 4)
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(5)

        # ignore first VM
        initial_instances = director.instances

        foobar1_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[0]
        foobar1_instance2 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[1]
        foobar1_instance3 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[2]

        bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{foobar1_instance2.instance_group_name}/#{foobar1_instance2.id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{foobar1_instance3.instance_group_name}/#{foobar1_instance3.id}", deployment_name: 'simple')

        # redeploy with different foobar1 templates
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'foobar1',
          jobs: [{ 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' }],
          instances: 2,
        )
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output, exit_code = deploy_simple_manifest(
          manifest_hash: manifest_hash,
          cloud_config_hash: cloud_config,
          failure_expected: true,
          return_exit_code: true,
        )

        expect(exit_code).to_not eq(0)
        expect(output).to include(
          "Instance Group 'foobar1' has 3 ignored instance(s). " \
          '2 instance(s) of that instance group were requested. Deleting ignored instances is not allowed.',
        )
      end
    end

    context 'when the ignored instances is equal to desired ones' do
      it 'deletes all non-ignored vms and leaves the ignored alone without updating them' do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 4)
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(5)

        initial_instances = director.instances

        foobar1_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[0]
        foobar1_instance2 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[1]
        foobar1_instance3 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[2]
        foobar1_instance4 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[3]

        bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{foobar1_instance2.instance_group_name}/#{foobar1_instance2.id}", deployment_name: 'simple')

        # ===================================================
        # redeploy with different foobar1 templates
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'foobar1',
          jobs: [{ 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' }],
          instances: 2,
        )
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        expect(output).to include("Deleting unneeded instances foobar1: foobar1/#{foobar1_instance3.id}")
        expect(output).to include("Deleting unneeded instances foobar1: foobar1/#{foobar1_instance4.id}")

        expect(output).to_not match(/Updating instance/)
        expect(output).to_not match(/Creating missing vms/)

        expect(
          output.split("\n").select do |e|
            /Deleting unneeded instances/ =~ e
          end.count,
        ).to eq(2)

        expect(director.instance(foobar1_instance1.instance_group_name, foobar1_instance1.id).ignore).to eq('true')
        expect(director.instance(foobar1_instance1.instance_group_name, foobar1_instance1.id).last_known_state).to eq('running')
        expect(director.instance(foobar1_instance2.instance_group_name, foobar1_instance2.id).ignore).to eq('true')
        expect(director.instance(foobar1_instance2.instance_group_name, foobar1_instance2.id).last_known_state).to eq('running')
      end
    end

    context 'when the ignored instances are fewer than the desired ones' do
      it 'should keep the ignored instances untouched and adjust the number of remaining functional instances' do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 5)
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(6)

        foobar1_instances = director.instances.select { |instance| instance.instance_group_name == 'foobar1' }
        ignored_instance1 = foobar1_instances[0]
        ignored_instance2 = foobar1_instances[1]

        bosh_runner.run("ignore #{ignored_instance1.instance_group_name}/#{ignored_instance1.id}", deployment_name: 'simple')
        bosh_runner.run("ignore #{ignored_instance2.instance_group_name}/#{ignored_instance2.id}", deployment_name: 'simple')

        # ===================================================
        # redeploy with different foobar1 templates
        manifest_hash['instance_groups'].clear
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'foobar1',
          jobs: [{ 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' }],
          instances: 3,
        )
        manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

        output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        expect(output.split("\n").select { |e| /Deleting unneeded instances/ =~ e && /foobar1/ =~ e }.count).to eq(2)
        expect(output.split("\n").select { |e| /Deleting unneeded instances/ =~ e }.count).to eq(2)

        expect(output.split("\n").select { |e| /Updating instance foobar1:/ =~ e }.count).to eq(1)
        expect(output.split("\n").select { |e| /Updating instance/ =~ e }.count).to eq(1)
        expect(output).to_not match(ignored_instance1.id)
        expect(output).to_not match(ignored_instance2.id)

        modified_instances = director.instances

        expect(modified_instances.count).to eq(4)

        expect(modified_instances.select { |instance| instance.ignore == 'true' }.count).to eq(2)
        expect(modified_instances.select do |instance|
          instance.ignore == 'true' && instance.instance_group_name == 'foobar1'
        end.count).to eq(2)
        expect(modified_instances.select { |instance| instance.instance_group_name == 'foobar1' }.count).to eq(3)
        expect(modified_instances.select { |instance| instance.instance_group_name == 'foobar2' }.count).to eq(1)
        expect(modified_instances.select { |instance| instance.id == ignored_instance1.id }.count).to eq(1)
        expect(modified_instances.select { |instance| instance.id == ignored_instance2.id }.count).to eq(1)
      end
    end
  end

  context 'when --recreate flag is passed' do
    it 'should recreate needed vms but leave the ignored ones alone' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 3)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 3)

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      # ignore first VM
      initial_instances = director.instances
      foobar1_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[0]
      foobar1_instance2 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[1]
      foobar1_instance3 = initial_instances.select { |instance| instance.instance_group_name == 'foobar1' }[2]

      foobar2_instance1 = initial_instances.select { |instance| instance.instance_group_name == 'foobar2' }[0]
      foobar2_instance2 = initial_instances.select { |instance| instance.instance_group_name == 'foobar2' }[1]
      foobar2_instance3 = initial_instances.select { |instance| instance.instance_group_name == 'foobar2' }[2]

      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'foobar1',
        jobs: [
          { 'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release' },
          { 'name' => 'job_2_with_pre_start_script', 'release' => 'bosh-release' },
        ],
        instances: 3,
      )
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 3)

      output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, recreate: true)

      modified_instances = director.instances

      expect(output).to_not match("Updating instance foobar1: foobar1/#{foobar1_instance1.id}")

      expect(
        output.split("\n").select do |e|
          /Updating instance/ =~ e && /foobar1/ =~ e
        end.count,
      ).to eq(2)

      expect(
        modified_instances.none? do |instance|
          instance.agent_id == foobar1_instance2.agent_id ||
          instance.agent_id == foobar1_instance3.agent_id ||
          instance.agent_id == foobar2_instance1.agent_id ||
          instance.agent_id == foobar2_instance2.agent_id ||
          instance.agent_id == foobar2_instance3.agent_id
        end,
      ).to eq(true)

      expect(
        modified_instances.select do |instance|
          instance.agent_id == foobar1_instance1.agent_id
        end.count,
      ).to eq(1)
    end
  end

  context 'when an attempt is made to delete an instance group from deployment' do
    it 'fails if the instance group contains ignored vms' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 2)
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 2)

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      initial_instances = director.instances
      foobar1_instance1 = initial_instances.select do |instance|
        instance.instance_group_name == 'foobar1' && instance.index == '0'
      end.first
      bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 2)

      output, exit_code = deploy_simple_manifest(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )

      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "You are trying to delete instance group 'foobar1', which contains ignored instance(s). Operation not allowed.",
      )
    end
  end
end
