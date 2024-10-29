require 'spec_helper'

describe 'network lifecycle', type: :integration do
  context 'disabled', type: :integration do
    with_reset_sandbox_before_each
    before { bosh_runner.reset }
    context 'when deploying a manifest with a manual network not marked as managed' do
      it 'should not attempt to create a subnet in the iaas' do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].first['instances'] = 1
        manifest_hash['instance_groups'].first['azs'] = ['z1']
        manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a' }]
        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(0)
      end
    end
  end

  context 'enabled', type: :integration do
    with_reset_sandbox_before_each(networks: { 'enable_cpi_management' => true })
    let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs }
    let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest_with_instance_groups }

    before do
      bosh_runner.reset
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['azs'] = ['z1']
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a' }]
    end

    context 'when deploying a manifest with a managed network' do
      it 'should fail when not configured with a subnet name' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]
        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect {
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        }.to raise_error(Bosh::Spec::BoshGoCliRunner::Error)
      end

      it 'should have unique subnet names' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet1',
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet2',
              'range' => '192.168.20.0/24',
              'gateway' => '192.168.20.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet1',
              'range' => '192.168.30.0/24',
              'gateway' => '192.168.30.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect {
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        }.to raise_error(Bosh::Spec::BoshGoCliRunner::Error)
      end

      it 'should not have both netmask_bits and range' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'netmask_bits' => 24,
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect {
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        }.to raise_error(Bosh::Spec::BoshGoCliRunner::Error)
      end

      it 'should create a subnet in the iaas for first deployment' do
        cloud_config_hash['networks'] = [
          {
            'name' => 'a',
            'type' => 'manual',
            'managed' => true,
            'subnets' => [
              {
                'azs' => ['z1'],
                'name' => 'dummysubnet1',
                'range' => '192.168.10.0/24',
                'gateway' => '192.168.10.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
            ],
          },
          {
            'name' => 'b',
            'type' => 'manual',
            'managed' => true,
            'subnets' => [
              {
                'azs' => ['z1'],
                'name' => 'dummysubnet2',
                'range' => '192.168.20.0/24',
                'gateway' => '192.168.20.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
            ],
          },
        ]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(1)
        subnet_invocation = create_network_invocations.first
        expect(subnet_invocation.inputs['subnet_definition']).to eq(
          'type' => 'manual',
          'range' => '192.168.10.0/24',
          'cloud_properties' => { 't0_id' => '123456', 'a' => 'b' },
          'gateway' => '192.168.10.1',
        )
      end

      it 'should not create a subnet in the iaas for following deployments' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet1',
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        3.times do |i|
          manifest_hash['name'] = "another-deployment-#{i}"
          deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end

        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(1)
      end

      it 'should reuse an orphaned network' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet1',
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        bosh_runner.run('delete-deployment', deployment_name: manifest_hash['name'])
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(1)
      end

      it 'should fetch valid subnet definitions for following deployments' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [
            {
              'azs' => ['z1'],
              'name' => 'dummysubnet1',
              'range' => '192.168.10.0/24',
              'gateway' => '192.168.10.1',
              'cloud_properties' => { 't0_id' => '123456' },
              'dns' => ['8.8.8.8'],
            },
          ],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(1)
        network_cid = networks.first
        3.times do |i|
          manifest_hash['name'] = "another-deployment-#{i}"
          deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
          create_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm').last
          expect(create_vm_invocation.inputs['networks']['a']['cloud_properties']).to eq('name' => network_cid)
        end
      end

      it 'should not accept a dynamic network marked as managed' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'dynamic',
          'managed' => true,
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect {
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        }.to raise_error(Bosh::Spec::BoshGoCliRunner::Error)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(0)
      end
    end

    it 'should create all subnets in the network definition' do
      exp_cpi_input = [
        {
          'type' => 'manual',
          'range' => '192.168.10.0/24',
          'gateway' => '192.168.10.1',
          'cloud_properties' => { 't0_id' => '1', 'a' => 'b' },
        },
        {
          'type' => 'manual',
          'range' => '192.168.20.0/24',
          'gateway' => '192.168.20.1',
          'cloud_properties' => { 't0_id' => '2', 'a' => 'b' },
        },
        {
          'type' => 'manual',
          'range' => '192.168.30.0/24',
          'gateway' => '192.168.30.1',
          'cloud_properties' => { 't0_id' => '3', 'a' => 'b', 'c' => 'd' },
        },
        {
          'type' => 'manual',
          'netmask_bits' => 24,
          'cloud_properties' => { 't0_id' => '4', 'a' => 'b', 'c' => 'd' },
        },
      ]
      subnets = [
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet1',
          'range' => '192.168.10.0/24',
          'gateway' => '192.168.10.1',
          'cloud_properties' => { 't0_id' => '1' },
          'dns' => ['8.8.8.8'],
        },
        {
          'azs' => %w[z1 z2],
          'name' => 'dummysubnet2',
          'range' => '192.168.20.0/24',
          'gateway' => '192.168.20.1',
          'cloud_properties' => { 't0_id' => '2' },
          'dns' => ['8.8.8.8'],
        },
        {
          'azs' => %w[z1 z2 z3],
          'name' => 'dummysubnet3',
          'range' => '192.168.30.0/24',
          'gateway' => '192.168.30.1',
          'cloud_properties' => { 't0_id' => '3' },
          'dns' => ['8.8.8.8'],
        },
        {
          'azs' => %w[z1 z2 z3],
          'name' => 'dummysubnet4',
          'netmask_bits' => 24,
          'cloud_properties' => { 't0_id' => '4' },
          'dns' => ['8.8.8.8'],
        },
      ]
      cloud_config_hash['networks'] = [{
        'name' => 'a',
        'type' => 'manual',
        'managed' => true,
        'subnets' => subnets,
      }]
      cloud_config_hash['azs'] << {
        'name' => 'z3',
        'cloud_properties' => { 'c' => 'd' },
      }
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
      expect(create_network_invocations.count).to eq(4)
      create_network_invocations.each do |subnet_invocation|
        cpi_input = subnet_invocation.inputs['subnet_definition']
        idx = exp_cpi_input.index(cpi_input)
        expect(idx).to be_truthy
        exp_cpi_input.delete_at(idx)
      end
      networks = current_sandbox.cpi.network_cids
      expect(networks.count).to eq(4)
    end

    it 'should clean up subnets if network creation stage fails' do
      cloud_config_hash['networks'] = [{
        'name' => 'a',
        'type' => 'manual',
        'managed' => true,
        'subnets' => [
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet1',
            'range' => '192.168.10.0/24',
            'gateway' => '192.168.10.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet2',
            'range' => '192.168.20.0/24',
            'gateway' => '192.168.20.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet3',
            'range' => '192.168.30.0/24',
            'gateway' => '192.168.30.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet4',
            'range' => '192.168.40.0/24',
            'gateway' => '192.168.40.1',
            'cloud_properties' => { 'error' => 'no t0 router id' },
            'dns' => ['8.8.8.8'],
          },
        ],
      }]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      expect {
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      }.to raise_error(Bosh::Spec::BoshGoCliRunner::Error)
      create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
      expect(create_network_invocations.count).to eq(4)
      delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
      expect(delete_network_invocations.count).to eq(3)
      networks = current_sandbox.cpi.network_cids
      expect(networks.count).to eq(0)
    end
  end
end
