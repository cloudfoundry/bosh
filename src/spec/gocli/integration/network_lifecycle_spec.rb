require_relative '../spec_helper'

describe 'network lifecycle', type: :integration do
  context 'disabled', type: :integration do
    with_reset_sandbox_before_each
    before { bosh_runner.reset }
    context 'when deploying a manifest with a manual network not marked as managed' do
      it 'should not attempt to create a subnet in the iaas' do
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs
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

        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
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
    let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs }
    let(:manifest_hash) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

    before do
      bosh_runner.reset
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['azs'] = ['z1']
      manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a' }]
      manifest_hash['instance_groups'] << {
        'instances' => 1,
        'azs' => ['z1'],
        'networks' => [{ 'name' => 'a' }],
        'name' => 'another_instance_group',
        'jobs' => [{ 'name' => 'foobar', 'properties' => {} }],
        'stemcell' => 'default',
        'vm_type' => 'a',
        'properties' => {},
      }
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
        expect do
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
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
        expect do
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
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
        expect do
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
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
        expect do
          deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
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
      expect do
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      end.to raise_error
      create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
      expect(create_network_invocations.count).to eq(4)
      delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
      expect(delete_network_invocations.count).to eq(3)
      networks = current_sandbox.cpi.network_cids
      expect(networks.count).to eq(0)
    end

    context 'update network' do
      let(:dummysubnet1) do
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet1',
          'range' => '192.168.10.0/24',
          'gateway' => '192.168.10.1',
          'cloud_properties' => { 't0_id' => '123456' },
          'dns' => ['8.8.8.8'],
        }
      end

      let(:dummysubnet2) do
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet2',
          'range' => '192.168.20.0/24',
          'gateway' => '192.168.20.1',
          'cloud_properties' => { 't0_id' => '123456' },
          'dns' => ['8.8.8.8'],
        }
      end

      let(:dummysubnet3) do
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet3',
          'netmask_bits' => 24,
          'cloud_properties' => { 't0_id' => '123456' },
          'dns' => ['8.8.8.8'],
        }
      end

      let(:dummysubnet4) do
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet4',
          'range' => '192.168.40.0/24',
          'gateway' => '192.168.40.1',
          'cloud_properties' => { 't0_id' => '123456' },
          'dns' => ['8.8.8.8'],
        }
      end

      let(:dummysubnet5) do
        {
          'azs' => ['z1'],
          'name' => 'dummysubnet5',
          'netmask_bits' => 16,
          'cloud_properties' => { 't0_id' => '123456' },
          'dns' => ['8.8.8.8'],
        }
      end

      it 'should create network in the iaas when subnets are added in cloud config' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'] << dummysubnet2

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
      end

      it 'should delete network in the iaas when subnets are removed from cloud config' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].delete_at(1)

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(1)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
        # check that another deploy doesnt cause any more network deletions
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should not delete network in the iaas when other deployments are outdated' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        manifest_hash['name'] = 'another-deployment'
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].delete_at(1)

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)
      end

      it 'should delete network in the iaas when all deployments are updated' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        first_deployment_name = manifest_hash['name']
        manifest_hash['name'] = 'another-deployment'
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        manifest_hash['name'] = 'another-deployment-2'
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].delete_at(1)

        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)

        bosh_runner.run('delete-deployment', deployment_name: first_deployment_name)

        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)

        manifest_hash['name'] = 'another-deployment'
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should update modified subnets' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].last['subnets'].last['gateway'] = '192.168.30.1'
        cloud_config_hash['networks'].last['subnets'].last['range'] = '192.168.30.0/24'
        cloud_config_hash['networks'].last['subnets'].first['dns'] = ['1.1.1.1']

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        exp_create_network_input = [
          {
            'type' => 'manual',
            'range' => '192.168.10.0/24',
            'gateway' => '192.168.10.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
          {
            'type' => 'manual',
            'range' => '192.168.20.0/24',
            'gateway' => '192.168.20.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
          {
            'type' => 'manual',
            'range' => '192.168.30.0/24',
            'gateway' => '192.168.30.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
        ]
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(3)
        create_network_invocations.each do |subnet_invocation|
          cpi_input = subnet_invocation.inputs['subnet_definition']
          idx = exp_create_network_input.index(cpi_input)
          expect(idx).to be_truthy
          exp_create_network_input.delete_at(idx)
        end
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should recreate subnet when modified from range definition to size definition' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['netmask_bits'] = 24
        cloud_config_hash['networks'].first['subnets'].first.delete('gateway')
        cloud_config_hash['networks'].first['subnets'].first.delete('range')

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(1)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should recreate subnet when modified from size definition to range definition' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet3],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.10.1'
        cloud_config_hash['networks'].first['subnets'].first['range'] = '192.168.10.0/24'
        cloud_config_hash['networks'].first['subnets'].first.delete('netmask_bits')

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(1)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should recreate subnet when modified from one size definition to another' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet3],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['netmask_bits'] = 16

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(1)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should not recreate subnet when dns is modified' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet3],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['dns'] = ['1.1.1.1']
        cloud_config_hash['networks'].first['subnets'].last['dns'] = ['2.2.2.2']

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)
      end

      it 'should recreate subnets when cloud properties are modified' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet3],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['range'] = '192.168.50.0/24'
        cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.50.1'
        cloud_config_hash['networks'].first['subnets'].first['cloud_properties'] = { 't0_id' => '987654' }
        cloud_config_hash['networks'].first['subnets'].last['cloud_properties'] = { 't0_id' => '34534' }

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(4)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(2)
      end

      it 'should not support adding new subnets that overlap with current subnets' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['name'] = 'new subnet'
        cloud_config_hash['networks'].first['subnets'].first['range'] = '192.168.10.0/26'
        cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.10.2'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect do
          deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
      end

      it 'should not support modifying a current subnet with an overlapping subnet' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['range'] = '192.168.10.0/26'
        cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.10.2'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        expect do
          deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        end.to raise_error
      end

      it 'should detect changes for subnet name only [range defined]' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['name'] = 'dummy-subnet-name-change'
        cloud_config_hash['networks'].first['subnets'].last['name'] = 'dummy-subnet2-name-change'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)
      end

      it 'subnet-name only changes should still recreate a [size defined] subnet' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet3],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['subnets'].first['name'] = 'another-dummy-subnet-name-change'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(2)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(1)
      end

      it 'should handle transferring a network from managed to unmanaged' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].first['managed'] = false
        cloud_config_hash['networks'].first['subnets'].first['name'] = 'another-dummy-subnet-name-change'
        cloud_config_hash['networks'].first['subnets'].first['range'] = '192.168.50.0/24'
        cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.50.1'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(1)
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(0)
      end

      it 'should add, remove, and update modified subnets' do
        cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'manual',
          'managed' => true,
          'subnets' => [dummysubnet1, dummysubnet2],
        }]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        cloud_config_hash['networks'].last['subnets'].last['gateway'] = '192.168.30.1'
        cloud_config_hash['networks'].last['subnets'].last['range'] = '192.168.30.0/24'
        cloud_config_hash['networks'].last['subnets'][0] = dummysubnet4

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        networks = current_sandbox.cpi.network_cids
        expect(networks.count).to eq(2)
        exp_create_network_input = [
          {
            'type' => 'manual',
            'range' => '192.168.10.0/24',
            'gateway' => '192.168.10.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
          {
            'type' => 'manual',
            'range' => '192.168.20.0/24',
            'gateway' => '192.168.20.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
          {
            'type' => 'manual',
            'range' => '192.168.30.0/24',
            'gateway' => '192.168.30.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
          {
            'type' => 'manual',
            'range' => '192.168.40.0/24',
            'gateway' => '192.168.40.1',
            'cloud_properties' => { 'a' => 'b', 't0_id' => '123456' },
          },
        ]
        create_network_invocations = current_sandbox.cpi.invocations_for_method('create_network')
        expect(create_network_invocations.count).to eq(4)
        create_network_invocations.each do |subnet_invocation|
          cpi_input = subnet_invocation.inputs['subnet_definition']
          idx = exp_create_network_input.index(cpi_input)
          expect(idx).to be_truthy
          exp_create_network_input.delete_at(idx)
        end
        delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
        expect(delete_network_invocations.count).to eq(2)
      end
    end
  end
end
