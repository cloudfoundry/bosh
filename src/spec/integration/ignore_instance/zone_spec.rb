require 'spec_helper'

describe 'ignoring zone', type: :integration do
  with_reset_sandbox_before_each

  context 'when not using static ips' do
    it 'doesnt rebalance ignored vms, selects new bootstrap node from ignored if needed, & errors removing az w/ ignored vms' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1', 'my-az2'],
      )

      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config['azs'] = [
        {
          'name' => 'my-az1',
        },
        {
          'name' => 'my-az2',
        },
      ]
      cloud_config['compilation']['az'] = 'my-az1'

      cloud_config['networks'].first['subnets'] = [
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1',
          'dns' => ['192.168.1.1', '192.168.1.2'],
          'reserved' => [],
          'cloud_properties' => {},
          'az' => 'my-az1',
        },
        {
          'range' => '192.168.2.0/24',
          'gateway' => '192.168.2.1',
          'dns' => ['192.168.2.1', '192.168.2.2'],
          'reserved' => [],
          'cloud_properties' => {},
          'az' => 'my-az2',
        },
      ]

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      orig_instances = director.instances

      expect(orig_instances.count).to eq(4)
      expect(orig_instances.select { |i| i.availability_zone == 'my-az1' }.count).to eq(2)
      expect(orig_instances.select { |i| i.availability_zone == 'my-az2' }.count).to eq(2)
      expect(orig_instances.select(&:bootstrap).count).to eq(1)

      az2_instances = orig_instances.select { |i| i.availability_zone == 'my-az2' }
      bosh_runner.run("ignore #{az2_instances[0].instance_group_name}/#{az2_instances[0].id}", deployment_name: 'simple')
      bosh_runner.run("ignore #{az2_instances[1].instance_group_name}/#{az2_instances[1].id}", deployment_name: 'simple')

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1', 'my-az2'],
      )
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      new_state_instances = director.instances

      expect(new_state_instances.count).to eq(2)
      expect(new_state_instances.select { |i| i.availability_zone == 'my-az1' }.count).to eq(0)
      expect(new_state_instances.select { |i| i.availability_zone == 'my-az2' }.count).to eq(2)
      expect(new_state_instances.select { |i| i.id == az2_instances[0].id }.count).to eq(1)
      expect(new_state_instances.select { |i| i.id == az2_instances[1].id }.count).to eq(1)
      expect(new_state_instances.select(&:bootstrap).count).to eq(1)

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include("Instance Group 'foobar1' no longer contains AZs [\"my-az2\"] where ignored instance(s) exist.")

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1', 'my-az2'],
      )
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1'],
      )
      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include("Instance Group 'foobar1' no longer contains AZs [\"my-az2\"] where ignored instance(s) exist.")
    end
  end

  context 'when using static IPs' do
    it 'balances vms, errors removing azs containing ignored vms, and errors removing static IP assigned to an ignored VM' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1', 'my-az2'],
      )
      manifest_hash['instance_groups'].first['networks'] = [
        {
          'name' => 'a',
          'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.2.10', '192.168.2.11'],
        },
      ]

      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config['azs'] = [
        {
          'name' => 'my-az1',
        },
        {
          'name' => 'my-az2',
        },
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
          'az' => 'my-az1',
        },
        {
          'range' => '192.168.2.0/24',
          'gateway' => '192.168.2.1',
          'dns' => ['192.168.2.1', '192.168.2.2'],
          'static' => ['192.168.2.10-192.168.2.20'],
          'reserved' => [],
          'cloud_properties' => {},
          'az' => 'my-az2',
        },
      ]

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      orig_instances = director.instances
      az1_instances = orig_instances.select { |i| i.availability_zone == 'my-az1' }
      az2_instances = orig_instances.select { |i| i.availability_zone == 'my-az2' }

      expect(orig_instances.count).to eq(4)
      expect(az1_instances.count).to eq(2)
      expect(az2_instances.count).to eq(2)
      expect(orig_instances.select(&:bootstrap).count).to eq(1)

      # =======================================================
      # ignore az2 vms
      bosh_runner.run("ignore #{az2_instances[0].instance_group_name}/#{az2_instances[0].id}", deployment_name: 'simple')
      bosh_runner.run("ignore #{az2_instances[1].instance_group_name}/#{az2_instances[1].id}", deployment_name: 'simple')

      # =======================================================
      # remove IPs used by non-ignored vms, should be good
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1', 'my-az2'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'static_ips' => ['192.168.2.10', '192.168.2.11'] }]

      output2 = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      expect(output2).to_not include('Updating instance')
      expect(output2).to include(
        "Deleting unneeded instances foobar1: foobar1/#{az1_instances[0].id} (#{az1_instances[0].index})",
      )
      expect(output2).to include(
        "Deleting unneeded instances foobar1: foobar1/#{az1_instances[1].id} (#{az1_instances[1].index})",
      )

      instances_state2 = director.instances
      expect(instances_state2.count).to eq(2)
      expect(instances_state2.select { |i| i.availability_zone == 'my-az1' }.count).to eq(0)
      expect(instances_state2.select { |i| i.availability_zone == 'my-az2' }.count).to eq(2)
      expect(instances_state2.select(&:bootstrap).count).to eq(1)

      # =======================================================
      # remove an ignored vm static IP, should error
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 1,
        azs: ['my-az1', 'my-az2'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'static_ips' => ['192.168.2.10'] }]

      output3, exit_code3 = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code3).to_not eq(0)
      expect(output3).to include(
        "In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. " \
        'This operation is not allowed.',
      )

      # =======================================================
      # remove an az that has ignored VMs, should error
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1', 'my-az2'],
      )
      manifest_hash['instance_groups'].first['networks'] = [
        {
          'name' => 'a',
          'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.2.10', '192.168.2.11'],
        },
      ]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 4,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [
        {
          'name' => 'a',
          'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13'],
        },
      ]

      output4, exit_code4 = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code4).to_not eq(0)
      expect(output4).to include(
        "In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. " \
        'This operation is not allowed.',
      )
    end
  end
end

