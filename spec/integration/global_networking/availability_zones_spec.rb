require 'spec_helper'

describe 'availability zones', type: :integration do
  with_reset_sandbox_before_each

  context 'when job is placed in an availability zone that has cloud properties.' do
    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
    end

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash['resource_pools'].first['cloud_properties'] = {
        'a' => 'rp_value_for_a',
        'e' => 'rp_value_for_e',
      }
      cloud_config_hash['availability_zones'] = [{
          'name' => 'my-az',
          'cloud_properties' => {
            'a' => 'az_value_for_a',
            'd' => 'az_value_for_d'
          }
        }]
      cloud_config_hash['networks'].first['subnets'].first['availability_zone'] = 'my-az'
      cloud_config_hash
    end

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1
      manifest_hash['jobs'].first['availability_zones'] = ['my-az']
      manifest_hash['jobs'].first['networks'] = [{'name' => cloud_config_hash['networks'].first['name']}]
      manifest_hash
    end

    it 'should reuse an instance when vm creation fails the first time' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      current_sandbox.cpi.commands.make_create_vm_always_fail
      manifest = simple_manifest
      manifest['jobs'].first['networks'].first['static_ips'] = ['192.168.1.10']

      deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      deploy_simple_manifest(manifest_hash: manifest)

      expect(director.vms.count).to eq(1)
    end

    it 'creates VM with properties from both availability zone and resource pool' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest)

      expect(director.vms.count).to eq(1)
      vm_cid = director.vms.first.cid

      expect(current_sandbox.cpi.read_cloud_properties(vm_cid)).to eq({
            'a' => 'rp_value_for_a',
            'd' => 'az_value_for_d',
            'e' => 'rp_value_for_e',
          })
    end

    it 'resurrects VMs with the correct AZs cloud_properties' do
      current_sandbox.with_health_monitor_running do
        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.vms.count).to eq(1)
        original_vm = director.vms.first
        expected_cloud_properties = {
          'a' => 'rp_value_for_a',
          'd' => 'az_value_for_d',
          'e' => 'rp_value_for_e',
        }

        expect(original_vm.availability_zone).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(original_vm.cid)).to eq(expected_cloud_properties)

        resurrected_vm = director.kill_vm_and_wait_for_resurrection(original_vm)

        expect(current_sandbox.cpi.read_cloud_properties(resurrected_vm.cid)).to eq(expected_cloud_properties)
        expect(resurrected_vm.availability_zone).to eq(original_vm.availability_zone)
      end
    end

    it 'exposes an availability zone for within the template spec for the instance' do
      deploy_from_scratch(manifest_hash: simple_manifest, cloud_config_hash: cloud_config_hash)

      foobar_vm = director.vm('foobar', '0')
      template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')

      expect(template).to include('availability_zone=my-az')
    end

    it 'places the job instance in the correct subnet in manual network based on the availability zone' do
      simple_manifest['jobs'].first['instances'] = 2
      simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']

      cloud_config_hash['availability_zones'] = [
        {
          'name' => 'my-az'
        },
        {
          'name' => 'my-az2'
        }
      ]

      cloud_config_hash['networks'].first['subnets'] = [
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1',
          'dns' => ['192.168.1.1', '192.168.1.2'],
          'reserved' => [],
          'cloud_properties' => {},
          'availability_zone' => 'my-az'
        },
        {
          'range' => '192.168.2.0/24',
          'gateway' => '192.168.2.1',
          'dns' => ['192.168.2.1', '192.168.2.2'],
          'reserved' => [],
          'cloud_properties' => {},
          'availability_zone' => 'my-az2'
        }
      ]

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest)

      expect(director.vms.count).to eq(2)
      first_vm = director.vms[0]
      second_vm = director.vms[1]

      expect(first_vm.ips).to eq('192.168.1.2')
      expect(second_vm.ips).to eq('192.168.2.2')
    end

    it 'places the job instance in the correct subnet in dynamic network based on the availability zone' do
      simple_manifest['jobs'].first['instances'] = 2
      simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']
      simple_manifest['jobs'].first['templates'] =[{'name' => 'foobar_without_packages'}]

      cloud_config_hash['availability_zones'] = [
        {
          'name' => 'my-az',
          'cloud_properties' => {'az_name' => 'my-az'}
        },
        {
          'name' => 'my-az2',
          'cloud_properties' => {'az_name' => 'my-az2'}
        }
      ]

      cloud_config_hash['networks'].first['type'] = 'dynamic'
      cloud_config_hash['networks'].first['subnets'] = [
        {
          'dns' => ['192.168.1.1'],
          'cloud_properties' => {'first-subnet-key' => 'first-subnet-value'},
          'availability_zone' => 'my-az'
        },
        {
          'dns' => ['192.168.2.1'],
          'cloud_properties' => {'second-subnet-key' => 'second-subnet-value'},
          'availability_zone' => 'my-az2'
        }
      ]

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      current_sandbox.cpi.commands.set_dynamic_ips_for_azs({
        'my-az' => '192.168.1.1',
        'my-az2' => '192.168.2.1'
      })
      deploy_simple_manifest(manifest_hash: simple_manifest)

      network_cloud_properties = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['cloud_properties']
      end

      expect(network_cloud_properties).to contain_exactly(
        {'first-subnet-key' => 'first-subnet-value'},
        {'second-subnet-key' => 'second-subnet-value'}
      )

      vms = director.vms
      expect(vms.count).to eq(2)

      expect(vms[0].ips).to eq('192.168.1.1')
      expect(current_sandbox.cpi.read_cloud_properties(vms[0].cid)).to eq({'az_name' => 'my-az', 'a' => 'rp_value_for_a', 'e' => 'rp_value_for_e'})

      expect(vms[1].ips).to eq('192.168.2.1')
      expect(current_sandbox.cpi.read_cloud_properties(vms[1].cid)).to eq({'az_name' => 'my-az2', 'a' => 'rp_value_for_a', 'e' => 'rp_value_for_e'})
    end

    context 'when adding azs to jobs with persistent disks' do
      it 'keeps all jobs in the same az when job count stays the same' do
        cloud_config_hash['availability_zones'] = [
          {
            'name' => 'my-az',
            'cloud_properties' => {
              'availability_zone' => 'my-az'
            }
          },
          {
            'name' => 'my-az2',
            'cloud_properties' => {
              'availability_zone' => 'my-az2',
            }
          },
        ]

        cloud_config_hash['networks'].first['subnets'] = [
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az'
          },
          {
            'range' => '192.168.2.0/24',
            'gateway' => '192.168.2.1',
            'dns' => ['192.168.2.1', '192.168.2.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az2'
          }
        ]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        simple_manifest['jobs'].first['instances'] = 2
        simple_manifest['jobs'].first['availability_zones'] = ['my-az']
        simple_manifest['jobs'].first['persistent_disk'] = 1024
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.vms.count).to eq(2)
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)['availability_zone']).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[1].cid)['availability_zone']).to eq('my-az')

        simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.vms.count).to eq(2)
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)['availability_zone']).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[1].cid)['availability_zone']).to eq('my-az')
      end

      it 'adds new jobs in the new az when scaling up job count' do
        cloud_config_hash['availability_zones'] = [
          {
            'name' => 'my-az',
            'cloud_properties' => {
              'availability_zone' => 'my-az'
            }
          },
          {
            'name' => 'my-az2',
            'cloud_properties' => {
              'availability_zone' => 'my-az2',
            }
          },
        ]

        cloud_config_hash['networks'].first['subnets'] = [
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az'
          },
          {
            'range' => '192.168.2.0/24',
            'gateway' => '192.168.2.1',
            'dns' => ['192.168.2.1', '192.168.2.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az2'
          }
        ]


        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        simple_manifest['jobs'].first['instances'] = 2
        simple_manifest['jobs'].first['availability_zones'] = ['my-az']
        simple_manifest['jobs'].first['persistent_disk'] = 1024
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.vms.count).to eq(2)
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)['availability_zone']).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[1].cid)['availability_zone']).to eq('my-az')

        simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']
        simple_manifest['jobs'].first['instances'] = 3
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.vms.count).to eq(3)
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)['availability_zone']).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[1].cid)['availability_zone']).to eq('my-az')
        expect(current_sandbox.cpi.read_cloud_properties(director.vms[2].cid)['availability_zone']).to eq('my-az2')
      end

      it 'updates instances when az cloud properties change and deployment is re-deployed' do
        cloud_hash = cloud_config_hash
        cloud_hash['availability_zones'] = [
          {
            'name' => 'my-az',
            'cloud_properties' => {
              'availability_zone' => 'my-az',
              'a' => 'should_be_overwritten_from_rp_cloud_properties',
              'b' => 'cp_value_for_b'
            }
          }
        ]

        cloud_hash['networks'].first['subnets'] = [
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az'
          }
        ]
        upload_cloud_config(cloud_config_hash: cloud_hash)

        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages')
        manifest['jobs'].first['availability_zones'] = ['my-az']

        deploy_simple_manifest(manifest_hash: manifest)

        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)).to eq({
              'availability_zone' => 'my-az',
              'b' => 'cp_value_for_b',
              'a' => 'rp_value_for_a',
              'e' => 'rp_value_for_e'
            })

        cloud_hash['availability_zones'] = [
          {
            'name' => 'my-az',
            'cloud_properties' => {
              'availability_zone' => 'my-az',
              'foo' => 'bar'
            }
          }
        ]

        upload_cloud_config(cloud_config_hash: cloud_hash)

        deploy_simple_manifest(manifest_hash: manifest)

        expect(current_sandbox.cpi.read_cloud_properties(director.vms[0].cid)).to eq({
          'availability_zone' => 'my-az',
          'a' => 'rp_value_for_a',
          'e' => 'rp_value_for_e',
          'foo' => 'bar'
        })

        expect(current_sandbox.cpi.invocations_for_method('delete_vm').count).to eq(1)
        expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(2)
      end
    end

    context 'when adding and deleting azs from jobs' do
      it 'selects a new bootstrap node if instance is deleted' do
        cloud_config_hash['availability_zones'] = [
          {
            'name' => 'my-az',
            'cloud_properties' => {
              'availability_zone' => 'my-az'
            }
          },
          {
            'name' => 'my-az2',
            'cloud_properties' => {
              'availability_zone' => 'my-az2',
            }
          },
        ]

        cloud_config_hash['networks'].first['subnets'] = [
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az'
          },
          {
            'range' => '192.168.2.0/24',
            'gateway' => '192.168.2.1',
            'dns' => ['192.168.2.1', '192.168.2.2'],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'my-az2'
          }
        ]

        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        simple_manifest['jobs'].first['instances'] = 2
        simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']
        deploy_simple_manifest(manifest_hash: simple_manifest)
        bootstrap_node = director.instances.find { |instance| instance.is_bootstrap }

        simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2'] - [bootstrap_node.az]
        deploy_simple_manifest(manifest_hash: simple_manifest)

        new_bootstrap_node = director.instances.find { |instance| instance.is_bootstrap }
        expect(bootstrap_node.id).not_to eq(new_bootstrap_node.id)

        simple_manifest['jobs'].first['availability_zones'] = ['my-az', 'my-az2']
        deploy_simple_manifest(manifest_hash: simple_manifest)

        current_bootstrap_node = director.instances.find { |instance| instance.is_bootstrap }
        expect(current_bootstrap_node.id).to eq(new_bootstrap_node.id)
      end
    end
  end
end
