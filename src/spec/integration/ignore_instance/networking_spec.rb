require 'spec_helper'

describe 'netowrking', type: :integration do
  with_reset_sandbox_before_each

  context 'when not using static ips' do
    it 'fails when adding/removing networks from instance groups with ignored VMs' do
      manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )

      cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
      cloud_config['azs'] = [{ 'name' => 'my-az1' }]
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
      ]

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      orig_instances = director.instances
      expect(orig_instances.count).to eq(2)

      bosh_runner.run("ignore #{orig_instances[0].instance_group_name}/#{orig_instances[0].id}", deployment_name: 'simple')

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
            'az' => 'my-az1',
          },
        ],
      }

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'default' => %w[dns gateway] }]
      manifest_hash['instance_groups'].first['networks'] << { 'name' => 'b' }

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. " \
        'This operation is not allowed.',
      )

      # =================================================
      # remove a network from the instance group that has ignored VM, should fail
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'b', 'default' => %w[dns gateway] }]

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. " \
        'This operation is not allowed.',
      )
    end
  end

  context 'when using static IPs' do
    it 'doesnt re-assign static IPs for ignored VM, and fails when adding/removing static networks' do
      manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11'] }]

      cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
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
      bosh_runner.run("ignore #{orig_instances[0].instance_group_name}/#{orig_instances[0].id}", deployment_name: 'simple')
      bosh_runner.run("ignore #{orig_instances[1].instance_group_name}/#{orig_instances[1].id}", deployment_name: 'simple')

      # =================================================
      # switch a static IP address used by an ignored VM, should fail
      manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.12'] }]

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "In instance group 'foobar1', an attempt was made to remove a static ip that is used by an ignored instance. " \
        'This operation is not allowed.',
      )

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
            'az' => 'my-az1',
          },
        ],
      }

      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [
        {
          'name' => 'a',
          'static_ips' => ['192.168.1.10', '192.168.1.11'],
          'default' => %w[dns gateway],
        },
      ]
      manifest_hash['instance_groups'].first['networks'] << { 'name' => 'b' }

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. " \
        'This operation is not allowed.',
      )

      # =================================================
      # remove a network from the instance group that has ignored VM, should fail
      manifest_hash['instance_groups'].clear
      manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'foobar1',
        instances: 2,
        azs: ['my-az1'],
      )
      manifest_hash['instance_groups'].first['networks'] = [
        {
          'name' => 'b',
          'static_ips' => ['192.168.1.10', '192.168.1.11'],
          'default' => %w[dns gateway],
        },
      ]

      output, exit_code = deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
      expect(output).to include(
        "In instance group 'foobar1', which contains ignored vms, an attempt was made to modify the networks. " \
        'This operation is not allowed.',
      )
    end
  end
end
