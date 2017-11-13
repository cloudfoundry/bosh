require_relative '../spec_helper'

describe 'deploy instance_groups job', type: :integration do
  with_reset_sandbox_before_each

  it 're-evaluates job with new manifest job properties' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'test_property' => 1 }
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    foobar_instance = director.instance('foobar', '0')

    template = foobar_instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=1')

    manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'test_property' => 2 }
    deploy_simple_manifest(manifest_hash: manifest_hash)

    template = foobar_instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=2')
  end

  it 're-evaluates job with new dynamic network configuration' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'network_name' => 'a' }

    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['networks'].first['type'] = 'dynamic'
    cloud_config_hash['networks'].first['cloud_properties'] = {}
    cloud_config_hash['networks'].first.delete('subnets')

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    # VM deployed for the first time knows about correct dynamic IP
    instance = director.instance('foobar', '0')
    template = instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.101')
    expect(template).to include("spec.address=#{instance.id}.foobar.a.simple.bosh")

    # Force VM recreation
    cloud_config_hash['vm_types'].first['cloud_properties'] = {'changed' => true}
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    # Recreated VM due to the resource pool change knows about correct dynamic IP
    instance = director.instance('foobar', '0')
    template = instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.102')
    expect(template).to include("spec.address=#{instance.id}.foobar.a.simple.bosh")
  end

  it 'does not redeploy if the order of properties get changed' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['jobs'].first['properties'] = {
        'test_property' =>
        {
            'q2GB' => 'foo',
            'q4GB' => 'foo',
            'q8GB' => 'foo',
            'q46GB' => 'foo',
            'q82GB' => 'foo',
            'q64GB' => 'foo',
            'q428GB' => 'foo',
        }
      }
      manifest_hash['instance_groups'].first['instances'] = 1

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      expect(director.instances.count).to eq(1)

      instance = director.instance('foobar', '0')
      template = instance.read_job_template('foobar', 'bin/foobar_ctl')
      expected_rendered_template = '"test_property={"q2GB"=>"foo", "q428GB"=>"foo", "q46GB"=>"foo", "q4GB"=>"foo", "q64GB"=>"foo", "q82GB"=>"foo", "q8GB"=>"foo"}"'
      expect(template).to include(expected_rendered_template)

      output = deploy(manifest_hash: manifest_hash)
      expect(output).to_not match(/Updating instance foobar/)

      instance = director.instance('foobar', '0')
      template = instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include(expected_rendered_template)
  end

  context 'health monitor', hm: true do
    with_reset_hm_before_each

    it 'creates alerts to mark the start and end of an update deployment' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      waiter.wait(60) do
        expect(health_monitor.read_log).to match(/\[ALERT\] Alert @ .* Begin update deployment for 'simple'/)
      end
      waiter.wait(120) do
        expect(health_monitor.read_log).to match(/\[ALERT\] Alert @ .* Finish update deployment for 'simple'/)
      end

      # delete this assertion on heartbeat output if it fails... This assertion adds ~60s to the suite. It's not worth it.
      waiter.wait(120) do
        expect(health_monitor.read_log).to match(/\[HEARTBEAT\] Heartbeat from \w.*\/\w.* \(agent_id=\w.*\)/)
      end
    end
  end
end
