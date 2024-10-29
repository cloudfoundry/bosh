require 'spec_helper'

describe 'vip networks', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'] << {
      'name' => 'vip-network',
      'type' => 'vip',
    }
    cloud_config_hash['networks'] << {
      'name' => 'wrong-vip-network-not-referenced-in-manifest',
      'type' => 'vip',
      'subnets' => [
        { 'static' => ['69.69.69.69'] },
      ],
    }
    cloud_config_hash
  end

  before do
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  context 'when the operator defines a vip in the instance group' do
    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network', 'static_ips' => ['69.69.69.69'] },
      ]
      manifest_hash
    end

    let(:updated_simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network', 'static_ips' => ['68.68.68.68', '69.69.69.69'] },
      ]
      manifest_hash
    end

    let(:client_env) do
      { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
    end

    it 'reuses instance vip network IP on subsequent deploy', no_create_swap_delete: true do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      deploy_simple_manifest(manifest_hash: updated_simple_manifest, recreate: true)

      new_instances = director.instances
      expect(new_instances.size).to eq(2)

      instance_with_original_vip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
      expect(instance_with_original_vip.id).to eq(original_instances.first.id)
      expect(instance_with_original_vip.ips).to eq(['192.168.1.2', '69.69.69.69'])

      instance_with_new_vip = new_instances.find { |new_instance| new_instance.ips.include?('68.68.68.68') }
      expect(instance_with_new_vip.ips).to eq(['192.168.1.3', '68.68.68.68'])
    end

    it 'shows no change on update' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network', 'static_ips' => ['69.69.69.69', '68.68.68.68'] },
      ]

      deploy_simple_manifest(manifest_hash: manifest_hash)
      second_deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)

      task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
      task_output = bosh_runner.run("task #{task_id} --debug",
                                    deployment_name: 'my-dep',
                                    include_credentials: true,
                                    env: client_env)
      expect(task_output).to include("No instances to update for 'foobar'")
      expect(task_output).not_to include('networks_changed? obsolete reservations:')

      new_instances = director.instances
      expect(new_instances.size).to eq(2)

      vm1 = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
      expect(vm1.ips).to eq(['192.168.1.2', '69.69.69.69'])

      vm2 = new_instances.find { |new_instance| new_instance.ips.include?('68.68.68.68') }
      expect(vm2.ips).to eq(['192.168.1.3', '68.68.68.68'])
    end
  end

  context 'when the operator predefines vips in the cloud config' do
    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network' },
      ]
      manifest_hash
    end

    let(:updated_simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network' },
      ]
      manifest_hash
    end

    before :each do
      cloud_config_hash['networks'][1]['subnets'] = [{ 'static' => ['69.69.69.69'] }]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
    end

    it 'reuses instance vip network IP on subsequent deploy', no_create_swap_delete: true do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      cloud_config_hash['networks'][1]['subnets'] = [{ 'static' => ['68.68.68.68', '69.69.69.69'] }]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: updated_simple_manifest, recreate: true)

      new_instances = director.instances
      expect(new_instances.size).to eq(2)

      instance_with_original_vip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
      expect(instance_with_original_vip.id).to eq(original_instances.first.id)
      expect(instance_with_original_vip.ips).to eq(['192.168.1.2', '69.69.69.69'])

      instance_with_new_vip = new_instances.find { |new_instance| new_instance.ips.include?('68.68.68.68') }
      expect(instance_with_new_vip.ips).to eq(['192.168.1.3', '68.68.68.68'])
    end

    it 'updates when the cloud config is changed', no_create_swap_delete: true do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      cloud_config_hash['networks'][1]['subnets'] = [{ 'static' => ['68.68.68.68'] }]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest, recreate: true)

      new_instances = director.instances
      expect(new_instances.size).to eq(1)
      expect(new_instances.first.ips).to eq(['192.168.1.2', '68.68.68.68'])
    end

    it 'successfully releases ip addresses after deletion', no_create_swap_delete: true do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      bosh_runner.run('delete-deployment', deployment_name: 'simple')

      deploy_simple_manifest(manifest_hash: simple_manifest, recreate: true)
      new_instances = director.instances
      expect(new_instances.size).to eq(1)
      expect(new_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])
    end

    it 'reuses ips when the network is renamed in cloud config' do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      cloud_config_hash['networks'][1]['name'] = 'vip-network2'
      cloud_config_hash['networks'][1]['subnets'] = [{ 'static' => ['68.68.68.68', '69.69.69.69'] }]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_with_renamed_vip_network = simple_manifest
      manifest_with_renamed_vip_network['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network2' },
      ]

      deploy_simple_manifest(manifest_hash: manifest_with_renamed_vip_network)
      new_instances = director.instances
      expect(new_instances.size).to eq(1)
      expect(new_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])
    end
  end

  context 'when migrating instance group defined vips to the cloud config' do
    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network', 'static_ips' => ['69.69.69.69', '68.68.68.68'] },
      ]
      manifest_hash
    end

    let(:updated_simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
        { 'name' => cloud_config_hash['networks'].first['name'], 'default' => %w[dns gateway] },
        { 'name' => 'vip-network-cc' },
      ]
      manifest_hash
    end

    it 'keeps the same vip through the migration' do
      deploy_simple_manifest(manifest_hash: simple_manifest)

      original_instances = director.instances
      expect(original_instances.size).to eq(2)

      instance_with_first_vip = original_instances.find { |instance| instance.ips.include?('69.69.69.69') }
      expect(instance_with_first_vip.ips).to eq(['192.168.1.2', '69.69.69.69'])
      instance_with_second_vip = original_instances.find { |instance| instance.ips.include?('68.68.68.68') }
      expect(instance_with_second_vip.ips).to eq(['192.168.1.3', '68.68.68.68'])

      cloud_config_hash['networks'] << {
        'name' => 'vip-network-cc',
        'type' => 'vip',
        'subnets' => [{
          'static' => ['70.70.70.70', '68.68.68.68', '69.69.69.69', '80.80.80.80'],
        }],
      }

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: updated_simple_manifest)

      new_instances = director.instances
      expect(new_instances.size).to eq(2)

      new_instance_with_first_vip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
      expect(new_instance_with_first_vip.id).to eq(instance_with_first_vip.id)
      expect(new_instance_with_first_vip.ips).to eq(['192.168.1.2', '69.69.69.69'])

      new_instance_with_second_vip = new_instances.find { |new_instance| new_instance.ips.include?('68.68.68.68') }
      expect(new_instance_with_second_vip.id).to eq(instance_with_second_vip.id)
      expect(new_instance_with_second_vip.ips).to eq(['192.168.1.3', '68.68.68.68'])
    end
  end
end
