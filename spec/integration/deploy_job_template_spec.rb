require 'spec_helper'

describe 'deploy job template', type: :integration do
  with_reset_sandbox_before_each

  it 're-evaluates job templates with new manifest job properties' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['properties'] = { 'test_property' => 1 }
    deploy_simple(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar/0')

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=1')

    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_simple_manifest(manifest_hash: manifest_hash)

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=2')
  end

  it 're-evaluates job templates with new dynamic network configuration' do
    # Ruby agent does not determine dynamic ip for dummy infrastructure
    pending if current_sandbox.agent_type == "ruby"

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['networks'].first['type'] = 'dynamic'
    manifest_hash['networks'].first['cloud_properties'] = {}
    manifest_hash['networks'].first.delete('subnets')
    manifest_hash['resource_pools'].first['size'] = 1
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['properties'] = { 'network_name' => 'a' }

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')
    deploy_simple(manifest_hash: manifest_hash)

    # VM deployed for the first time knows about correct dynamic IP
    template = director.vm('foobar/0').read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.101')

    # Force VM recreation
    manifest_hash['resource_pools'].first['cloud_properties'] = {'changed' => true}

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    # Recreated VM due to the resource pool change knows about correct dynamic IP
    template = director.vm('foobar/0').read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.102')
  end
end
