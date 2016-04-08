require 'spec_helper'

describe 'deleting deployment', type: :integration do
  with_reset_sandbox_before_each

  it 'should clean environment properly and free up resources' do
    target_and_login

    expect(current_sandbox.cpi.all_stemcells).to eq []
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    expect(bosh_runner.run('deployments', failure_expected: true)).to match /No deployments/

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')
    cloud_config_hash['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'disk_a'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)
    expect(bosh_runner.run('take snapshot foobar 0')).to include('Snapshot taken')

    expect(bosh_runner.run('deployments')).to include('Deployments total: 1')
    expect(bosh_runner.run('vms')).to include('VMs total: 1')
    expect(bosh_runner.run('instances')).to include('Instances total: 1')
    expect(bosh_runner.run('releases')).to include('Releases total: 1')

    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(current_sandbox.cpi.vm_cids.count).to eq 1
    expect(current_sandbox.cpi.disk_cids.count).to eq 1
    expect(current_sandbox.cpi.all_ips.count).to eq 1
    expect(current_sandbox.cpi.all_snapshots.count).to eq 1

    # Delete Deployment
    deployment_deletion_output = scrub_random_ids(bosh_runner.run('delete deployment simple'))
    expect(deployment_deletion_output).to include('Started deleting instances > foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)')
    expect(deployment_deletion_output).to include('Deleted deployment')

    # Stemcells and releases remain after deletion of deployment
    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(bosh_runner.run('releases')).to include('Releases total: 1')

    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 1
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 1

    #deployments
    expect(bosh_runner.run('deployments', failure_expected: true)).to match /No deployments/
  end

  it 'should clean environment properly and free up resources even after a failed deployment' do
    current_sandbox.cpi.commands.make_create_vm_always_fail
    target_and_login

    expect(current_sandbox.cpi.all_stemcells).to eq []
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    expect(bosh_runner.run('deployments', failure_expected: true)).to match /No deployments/

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')
    cloud_config_hash['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'disk_a'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, failure_expected: true)

    expect(bosh_runner.run('deployments')).to include('Deployments total: 1')
    expect(bosh_runner.run('vms')).to include('No VMs')
    expect(bosh_runner.run('instances')).to include('No instances')
    expect(bosh_runner.run('releases')).to include('Releases total: 1')

    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0

    # Delete Deployment
    expect(bosh_runner.run('delete deployment simple')).to include('Deleted deployment')
    # puts bosh_runner.run('delete deployment simple', failure_expected: true)

    # Stemcells and releases remain after deletion of deployment
    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(bosh_runner.run('releases')).to include('Releases total: 1')

    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    #deployments
    expect(bosh_runner.run('deployments', failure_expected: true)).to include('No deployments')
  end
end
