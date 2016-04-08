require 'spec_helper'

describe 'failing deploy', type: :integration do
  with_reset_sandbox_before_each

  it 'keeps automatically assigned IP address when vm creation fails' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 1, template: 'foobar_without_packages')
    deploy_from_scratch(manifest_hash: first_manifest_hash, failure_expected: true)

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.2'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1, template: 'foobar_without_packages')
    deploy_simple_manifest(manifest_hash: second_manifest_hash)

    expect(director.vms('second').map(&:ips)).to eq(['192.168.1.3'])

    deploy_simple_manifest(manifest_hash: first_manifest_hash)
    expect(director.vms('first').map(&:ips)).to eq(['192.168.1.2'])
  end

  it 'keeps static IP address when vm creation fails' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 1, template: 'foobar_without_packages', static_ips: ['192.168.1.10'])
    deploy_from_scratch(manifest_hash: first_manifest_hash, failure_expected: true)

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.10'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1, template: 'foobar_without_packages', static_ips: ['192.168.1.10'])
    second_deploy_output = deploy_simple_manifest(manifest_hash: second_manifest_hash, failure_expected: true)
    expect(second_deploy_output).to match(/Failed to reserve IP '192.168.1.10' for instance 'foobar\/0 \(.+\)': already reserved by instance 'foobar\/0' from deployment 'first'/)

    deploy_simple_manifest(manifest_hash: first_manifest_hash)
    expect(director.vms('first').map(&:ips)).to eq(['192.168.1.10'])
  end

  it 'releases unneeded IP addresses when deploy is no longer failing' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages', static_ips: ['192.168.1.10'])
    deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true)

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.10'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed
    manifest_hash['jobs'].first['networks'].first.delete('static_ips')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    expect(director.vms.map(&:ips)).to eq(['192.168.1.2'])

    second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1, template: 'foobar_without_packages', static_ips: ['192.168.1.10'])
    deploy_simple_manifest(manifest_hash: second_manifest_hash)
    expect(director.vms('second').map(&:ips)).to eq(['192.168.1.10'])
  end

  it 'releases IP when subsequent deploy does not need failing instance' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages')
    deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true)

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.2'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(name: 'second-job', instances: 1)]
    deploy_simple_manifest(manifest_hash: manifest_hash)
    # IPs are not released within single deployment
    # see https://www.pivotaltracker.com/story/show/98057020
    expect(director.vms.map(&:ips)).to eq(['192.168.1.3'])
  end
end
