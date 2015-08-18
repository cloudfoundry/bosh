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

  end
end
