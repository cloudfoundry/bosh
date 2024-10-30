require 'spec_helper'

describe 'global networking', type: :integration do
  with_reset_sandbox_before_each

  def deploy_with_ip(manifest, ip, options = {})
    deploy_with_ips(manifest, [ip], options)
  end

  def deploy_with_ips(manifest, ips, options = {})
    manifest['instance_groups'].first['networks'].first['static_ips'] = ips
    manifest['instance_groups'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_legacy_with_ips(manifest, ips, options = {})
    manifest['jobs'].first['networks'].first['static_ips'] = ips
    manifest['jobs'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_with_range(deployment_name, range)
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2, range: range) # 1 for compilation
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: deployment_name, instances: 1)
    deploy_simple_manifest(manifest_hash: first_manifest_hash)
  end

  def deploy_with_static_ip(deployment_name, ip, range)
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2, range: range) # 1 for compilation
    cloud_config_hash['networks'].first['subnets'].first['static'] << ip
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: deployment_name, instances: 1)
    deploy_with_ips(first_manifest_hash, [ip])
  end

  context 'when allocating dynamic IPs' do
    before do
      create_and_upload_test_release
      upload_stemcell
    end

    context 'when using two networks' do
      context 'when range does not include one of IPs' do
        def make_network_spec(first_subnet, second_subnet)
          [
            {
              'name' => 'first',
              'subnets' => [first_subnet],
            },
            {
              'name' => 'second',
              'subnets' => [second_subnet],
            },
          ]
        end

        let(:instance_group_with_two_networks) do
          instance_group_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(instances: 1)
          instance_group_spec['networks'] = [
            { 'name' => 'first', 'default' => %w[dns gateway] },
            { 'name' => 'second' },
          ]
          instance_group_spec
        end

        it 'redeploys VM updating IP that does not belong to range and keeping another IP', no_create_swap_delete: true do
          first_subnet = SharedSupport::DeploymentManifestHelper.make_subnet(available_ips: 2, range: '192.168.1.0/24') # 1 for compilation
          second_subnet = SharedSupport::DeploymentManifestHelper.make_subnet(available_ips: 1, range: '10.10.0.0/24')

          cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
          cloud_config_hash['networks'] = make_network_spec(first_subnet, second_subnet)
          cloud_config_hash['compilation']['network'] = 'first'
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
          manifest_hash['instance_groups'] = [instance_group_with_two_networks]
          deploy_simple_manifest(manifest_hash: manifest_hash)

          instances = director.instances
          expect(instances.size).to eq(1)
          expect(instances.map(&:ips).flatten).to match_array(['192.168.1.2', '10.10.0.2'])

          new_second_subnet = SharedSupport::DeploymentManifestHelper.make_subnet(available_ips: 1, range: '10.10.0.0/24', shift_ip_range_by: 1)
          cloud_config_hash['networks'] = make_network_spec(first_subnet, new_second_subnet)
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          deploy_simple_manifest(manifest_hash: manifest_hash)

          instances = director.instances
          expect(instances.size).to eq(1)
          expect(instances.map(&:ips).flatten).to match_array(['192.168.1.2', '10.10.0.3'])
        end
      end
    end
  end
end
