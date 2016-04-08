require 'spec_helper'

describe 'network configuration', type: :integration do
  with_reset_sandbox_before_each

  it 'reserves first available dynamic ip' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first['size'] = 3
    cloud_config_hash['networks'].first['subnets'][0] = {
      'range'    => '192.168.1.0/24',
      'gateway'  => '192.168.1.1',
      'dns'      => ['192.168.1.1'],
      'static'   => ['192.168.1.11', '192.168.1.14'],
      'reserved' => %w(
        192.168.1.2-192.168.1.10
        192.168.1.12-192.168.1.13
        192.168.1.20-192.168.1.254
      ),
      'cloud_properties' => {},
    }

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 3

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    # Available dynamic ips - 192.168.1.15 - 192.168.1.19
    output = bosh_runner.run('vms')
    expect(output).to match(/foobar.* 192\.168\.1\.15/)
    expect(output).to match(/foobar.* 192\.168\.1\.16/)
    expect(output).to match(/foobar.* 192\.168\.1\.17/)
  end

  it 'recreates VM when specifying static IP on job' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'].first['subnets'].first['static'] = %w(192.168.1.100)
    cloud_config_hash['resource_pools'].first['size'] = 1

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    manifest_hash['jobs'].first['networks'].first['static_ips'] = '192.168.1.100'
    deploy_simple_manifest(manifest_hash: manifest_hash)

    output = bosh_runner.run('vms')
    expect(output).to match(/192\.168\.1\.100/)
  end

  context 'Network settings are changed' do
    let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }

    it 'recreates VM when DNS nameservers are changed' do
      cloud_config_hash['networks'].first['subnets'].first['dns'] = ['8.8.8.8']

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      director.vms.each do |vm|
        expect(vm.get_state['networks']['a']['dns']).to match_array(['8.8.8.8'])
      end

      cloud_config_hash['networks'].first['subnets'].first['dns'] = ['8.8.8.8', '127.0.0.5']

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      director.vms.each do |vm|
        expect(vm.get_state['networks']['a']['dns']).to match_array(['8.8.8.8', '127.0.0.5'])
      end
    end

    it 'recreates VM when gateway is changed' do
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.1.254'

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      director.vms.each do |vm|
        expect(vm.get_state['networks']['a']['gateway']).to eq '192.168.1.254'
      end
    end
  end

  it 'preserves existing network reservations on a second deployment' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    subnet = {                                      # For routed subnets larger than /31 or /32,
      'range'    => '192.168.1.0/29',               # the number of available host addresses is usually reduced by two,
      'gateway'  => '192.168.1.1',                  # namely the largest address, which is reserved as the broadcast address,
      'dns'      => ['192.168.1.1', '192.168.1.2'], # and the smallest address, which identifies the network itself.
      'static'   => [],                             # range(8) - identity(1) - broadcast(1) - dns(2) = 4 available IPs
      'reserved' => [],
      'cloud_properties' => {},
    }
    cloud_config_hash['networks'].first['subnets'][0] = subnet
    cloud_config_hash['resource_pools'].first['size'] = 4

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 4

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash) # expected to not failed
  end

  it 'does not recreate VM when re-deploying with legacy (non-cloud-config) unchanged dynamic and vip networking' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'] = [{
        'name' => 'a',
        'type' => 'dynamic',
        'cloud_properties' => {}
      },
      {
        'name' => 'b',
        'type' => 'vip',
        'static_ips' => ['69.69.69.69'],
      }
    ]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['networks'].first['default'] = ['dns', 'gateway']
    manifest_hash['jobs'].first['networks'] << {'name' => 'b', 'static_ips' => ['69.69.69.69']}

    legacy_manifest = manifest_hash.merge(cloud_config_hash)

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')

    deploy_from_scratch(manifest_hash: legacy_manifest, legacy: true)
    agent_id = director.vms.first.agent_id
    deploy_simple_manifest(manifest_hash: legacy_manifest, legacy: true)
    expect(director.vms.map(&:agent_id)).to eq([agent_id])
  end

  it 'does not recreate VM when re-deploying with cloud-config unchanged dynamic and vip networking' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'] = [{
        'name' => 'a',
        'type' => 'dynamic',
        'cloud_properties' => {}
      },
      {
        'name' => 'b',
        'type' => 'vip',
        'static_ips' => ['69.69.69.69'],
      }
    ]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['networks'].first['default'] = ['dns', 'gateway']
    manifest_hash['jobs'].first['networks'] << {'name' => 'b', 'static_ips' => ['69.69.69.69']}

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash) # expected to not failed
    agent_id = director.vms.first.agent_id
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect(director.vms.map(&:agent_id)).to eq([agent_id])
  end
end
