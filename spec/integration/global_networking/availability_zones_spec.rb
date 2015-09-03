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
        expect(current_sandbox.cpi.read_cloud_properties(original_vm.cid)).to eq(expected_cloud_properties)

        resurrected_vm = director.kill_vm_and_wait_for_resurrection(original_vm)

        expect(current_sandbox.cpi.read_cloud_properties(resurrected_vm.cid)).to eq(expected_cloud_properties)
      end
    end

    it 'exposes an availability zone for within the template spec for the instance' do
      deploy_from_scratch(manifest_hash: simple_manifest, cloud_config_hash: cloud_config_hash)

      foobar_vm = director.vm('foobar/0')
      template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')

      expect(template).to include('availability_zone=my-az')
    end

    it 'places the job instance in the correct subnet based on the availability zone' do
      current_sandbox.with_health_monitor_running do
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

    end
  end
end
