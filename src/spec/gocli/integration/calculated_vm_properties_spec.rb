require_relative '../spec_helper'

describe 'calculated vm properties', type: :integration do
  with_reset_sandbox_before_each

  let(:vm_resources) {
    {
      'cpu' => 2,
      'ram' => 1024,
      'ephemeral_disk_size' => 10
    }
  }

  let(:cloud_config_without_vm_types) do
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config.delete('resource_pools')
    cloud_config.delete('vm_types')
    cloud_config['compilation'].delete('cloud_properties')
    cloud_config['compilation']['vm_resources'] = vm_resources
    cloud_config
  end

  let(:cpi_config) { Bosh::Spec::Deployments.simple_cpi_config }

  let(:instance_group) do
    {
      'name' => 'dummy',
      'instances' => 1,
      'vm_resources' => vm_resources,
      'jobs' => [{'name'=> 'foobar', 'release' => 'bosh-release'}],
      'stemcell' => 'default',
      'networks' => [
        {
          'name' => 'a',
          'static_ips' => ['192.168.1.10', '192.168.2.10']
        }
      ]
    }
  end

  let(:deployment_manifest_with_vm_block) do
    {
      'name' => 'simple',
      'director_uuid'  => 'deadbeef',

      'releases' => [{
        'name'    => 'bosh-release',
        'version' => '0.1-dev',
      }],

      'instance_groups' => [
        {
          'name' => 'dummy',
          'instances' => 1,
          'vm_resources' => vm_resources,
          'jobs' => [{'name'=> 'foobar', 'release' => 'bosh-release'}],
          'stemcell' => 'default',
          'networks' => [
            {
              'name' => 'a',
              'static_ips' => ['192.168.1.10']
            }
          ]
        }
      ],

      'stemcells' => [
        {
          'alias' => 'default',
          'os' => 'toronto-os',
          'version' => '1',
        }
      ],

      'update' => {
        'canaries'          => 2,
        'canary_watch_time' => 4000,
        'max_in_flight'     => 1,
        'update_watch_time' => 20
      }
    }
  end

  context 'when deploying with default CPI' do
    before do
      create_and_upload_test_release
      upload_stemcell
      upload_cloud_config(cloud_config_hash: cloud_config_without_vm_types)
      deploy_simple_manifest(manifest_hash: deployment_manifest_with_vm_block)
    end

    it 'deploys vms with size calculated from vm block' do
      invocations = current_sandbox.cpi.invocations

      expect(invocations.select {|inv| inv.method_name == 'calculate_vm_cloud_properties'}.count).to eq(1)

      expect(invocations[2].method_name).to eq('calculate_vm_cloud_properties')
      expect(invocations[2].inputs['vm_resources']).to eq(vm_resources)

      invocations.select {|inv| inv.method_name == 'create_vm'}.each do |inv|
        expect(inv.inputs['cloud_properties']).to eq({"instance_type"=>"dummy", "ephemeral_disk"=>{"size"=>10}})
      end
    end

    context 'when deploying again without changes' do
      it 'uses the CPI again to calculate the vm cloud properties' do
        deploy_simple_manifest(manifest_hash: deployment_manifest_with_vm_block)

        invocations = current_sandbox.cpi.invocations

        expect(invocations.select {|inv| inv.method_name == 'calculate_vm_cloud_properties'}.count).to eq(2)
        expect(invocations.select {|inv| inv.method_name == 'create_vm'}.count).to eq(3)
      end
    end

    context 'when deploying again with changes to the vm requirements' do
      it 'uses the CPI again to calculate the vm cloud properties' do
        vm_resources['ephemeral_disk_size'] = 20
        deploy_simple_manifest(manifest_hash: deployment_manifest_with_vm_block)

        invocations = current_sandbox.cpi.invocations

        expect(invocations.select {|inv| inv.method_name == 'calculate_vm_cloud_properties'}.count).to eq(2)
        expect(invocations.select {|inv| inv.method_name == 'create_vm'}.count).to eq(4)
      end
    end
  end

  context 'when using vm_type and vm_block in different instance groups' do
    let(:cloud_config_with_vm_types_and_vm_resources) do
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config.delete('resource_pools')
      cloud_config['vm_types'] = [{'name' => 'vm_type_1', 'cloud_properties' => { 'instance_type' => 'from-vm-type'}}]
      cloud_config['compilation'].delete('vm_type')
      cloud_config['compilation']['cloud_properties'].delete('instance_type')
      cloud_config['compilation']['vm_resources'] = vm_resources
      cloud_config['networks'].first['subnets'].first['static'] << '192.168.1.11'
      cloud_config
    end
    let(:deployment_manifest_with_vm_block_and_vm_type) do
      deployment_manifest_with_vm_block['instance_groups'] <<  {
        'name' => 'dummy2',
        'instances' => 1,
        'vm_type' => 'vm_type_1',
        'jobs' => [{'name'=> 'foobar', 'release' => 'bosh-release'}],
        'stemcell' => 'default',
        'networks' => [
          {
            'name' => 'a',
            'static_ips' => ['192.168.1.11']
          }
        ]
      }

      deployment_manifest_with_vm_block
    end

    before do
      create_and_upload_test_release
      upload_stemcell
      upload_cloud_config(cloud_config_hash: cloud_config_with_vm_types_and_vm_resources)
      deploy_simple_manifest(manifest_hash: deployment_manifest_with_vm_block_and_vm_type)
    end

    it 'uses vm_type only for the instance_groups referencing it' do
      invocations = current_sandbox.cpi.invocations

      create_vm_cloud_properties = invocations.select{|inv| inv.method_name == 'create_vm'}.map{|inv| inv.inputs['cloud_properties']}
      expect(create_vm_cloud_properties.select {|props| props['instance_type'] == 'dummy'}.count).to eq(3)
      expect(create_vm_cloud_properties.select {|props| props['instance_type'] == 'from-vm-type'}.count).to eq(1)
    end
  end

  context 'when deploying with multiple CPIs' do
    let(:multi_cpi_cloud_config) do
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs_and_cpis
      cloud_config.delete('resource_pools')
      cloud_config.delete('vm_types')
      cloud_config['compilation'].delete('cloud_properties')
      cloud_config['compilation']['vm_resources'] = vm_resources
      cloud_config
    end
    let(:cpi_config) do
      cpi_config = Bosh::Spec::Deployments.simple_cpi_config(current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI))
      cpi_config['cpis'][0]['properties'] = { 'cvcpkey' => 'dummy1' }
      cpi_config['cpis'][1]['properties'] = { 'cvcpkey' => 'dummy2' }
      cpi_config
    end
    let(:instance_group_multi_az) { instance_group.merge('azs' => ['z1', 'z2'], 'instances' => 2) }
    let(:multi_cpi_deployment_manifest) { deployment_manifest_with_vm_block.merge('instance_groups' => [instance_group_multi_az]) }

    before do
      create_and_upload_test_release
      upload_cloud_config(cloud_config_hash: multi_cpi_cloud_config)
      cpi_config_manifest = yaml_file('simple', cpi_config)
      bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
      upload_stemcell
      deploy_simple_manifest(manifest_hash: multi_cpi_deployment_manifest)
    end

    it 'calculates vm cloud properties for each CPI' do
      invocations = current_sandbox.cpi.invocations

      cvcp_calls = invocations.select {|inv| inv.method_name == 'calculate_vm_cloud_properties'}
      expect(cvcp_calls.size).to eq(2)

      expect(cvcp_calls.select {|call| call.context['cvcpkey'] == 'dummy1'}.count).to eq(1)
      expect(cvcp_calls.select {|call| call.context['cvcpkey'] == 'dummy2'}.count).to eq(1)

      cvcp_calls.each do |inv|
        expect(inv.inputs['vm_resources']).to eq(vm_resources)
      end

      create_vm_calls_instance_types = invocations.select {|inv| inv.method_name == 'create_vm'}.map(&:inputs).map { |v| v['cloud_properties']['instance_type'] }
      expect(create_vm_calls_instance_types.select {|type| type == 'dummy1'}.count).to eq(3)
      expect(create_vm_calls_instance_types.select {|type| type == 'dummy2'}.count).to eq(1)
    end
  end

end
