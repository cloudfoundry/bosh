require_relative '../spec_helper'

describe 'deploy job template', type: :integration do
  with_reset_sandbox_before_each

  it 're-evaluates job templates with new manifest job properties' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['properties'] = { 'test_property' => 1 }
    deploy_from_scratch(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar', '0')

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=1')

    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_simple_manifest(manifest_hash: manifest_hash)

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=2')
  end

  it 're-evaluates job templates with new dynamic network configuration' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['properties'] = { 'network_name' => 'a' }

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'].first['type'] = 'dynamic'
    cloud_config_hash['networks'].first['cloud_properties'] = {}
    cloud_config_hash['networks'].first.delete('subnets')
    cloud_config_hash['resource_pools'].first['size'] = 1

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    # VM deployed for the first time knows about correct dynamic IP
    vm = director.vm('foobar', '0')
    template = vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.101')
    expect(template).to include("spec.address=#{vm.instance_uuid}.foobar.a.simple.bosh")

    # Force VM recreation
    cloud_config_hash['resource_pools'].first['cloud_properties'] = {'changed' => true}
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    # Recreated VM due to the resource pool change knows about correct dynamic IP
    vm = director.vm('foobar', '0')
    template = vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.102')
    expect(template).to include("spec.address=#{vm.instance_uuid}.foobar.a.simple.bosh")
  end

  context 'health monitor', hm: true do
    before { current_sandbox.health_monitor_process.start }
    after { current_sandbox.health_monitor_process.stop }

    it 'creates alerts to mark the start and end of an update deployment' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1

      deploy_from_scratch(manifest_hash: manifest_hash)

      waiter.wait(60) do
        expect(health_monitor.read_log).to match(/\[ALERT\] Alert @ .* Begin update deployment for 'simple'/)
      end
      waiter.wait(60) do
        expect(health_monitor.read_log).to match(/\[ALERT\] Alert @ .* Finish update deployment for 'simple'/)
      end

      # delete this assertion on heartbeat output if it fails... This assertion adds ~60s to the suite. It's not worth it.
      waiter.wait(120) do
        expect(health_monitor.read_log).to match(/\[HEARTBEAT\] Heartbeat from \w.*\/\w.* \(agent_id=\w.*\)/)
      end
    end
  end
end
