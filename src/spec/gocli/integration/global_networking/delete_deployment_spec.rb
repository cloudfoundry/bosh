require_relative '../../spec_helper'

describe 'deleting deployment', type: :integration do
  with_reset_sandbox_before_each

  it 'should clean environment properly and free up resources' do
    expect(current_sandbox.cpi.all_stemcells).to eq []
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    expect(bosh_runner.run('deployments', failure_expected: true)).to match /0 deployments/

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')
    cloud_config_hash['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'disk_a'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)
    expect(bosh_runner.run('take-snapshot foobar/0', deployment_name: 'simple')).to include('Succeeded')

    expect(bosh_runner.run('deployments')).to include('1 deployments')
    expect(bosh_runner.run('vms', deployment_name: 'simple')).to include('1 vms')
    expect(bosh_runner.run('instances', deployment_name: 'simple')).to include('1 instances')
    expect(bosh_runner.run('releases', deployment_name: 'simple')).to include('1 releases')

    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(current_sandbox.cpi.vm_cids.count).to eq 1
    expect(current_sandbox.cpi.disk_cids.count).to eq 1
    expect(current_sandbox.cpi.all_ips.count).to eq 1
    expect(current_sandbox.cpi.all_snapshots.count).to eq 1

    # Delete Deployment
    deployment_deletion_output = bosh_runner.run('delete-deployment', deployment_name: 'simple', json: true)
    expect(deployment_deletion_output).to match /Deleting instances: foobar/
    expect(deployment_deletion_output).to include('Succeeded')

    # Stemcells and releases remain after deletion of deployment
    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(bosh_runner.run('releases')).to include('1 releases')

    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 1
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 1

    #deployments
    expect(bosh_runner.run('deployments', failure_expected: true)).to match /0 deployments/
  end

  it 'should clean environment properly and free up resources even after a failed deployment' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    expect(current_sandbox.cpi.all_stemcells).to eq []
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    expect(bosh_runner.run('deployments', failure_expected: true)).to match /0 deployments/

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')
    cloud_config_hash['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'disk_a'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, failure_expected: true)

    expect(bosh_runner.run('deployments')).to include('1 deployments')
    expect(bosh_runner.run('vms', deployment_name: 'simple')).to include('0 vms')
    output = scrub_random_ids(table(bosh_runner.run('instances', deployment_name: 'simple', json: true)))
    expect(output).to contain_exactly({'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => '', 'az' => '', 'ips' => '192.168.1.2' })
    expect(bosh_runner.run('releases')).to include('1 releases')

    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0

    # Delete Deployment
    deployment_deletion_output = bosh_runner.run('delete-deployment', deployment_name: 'simple', json: true)
    expect(deployment_deletion_output).to match /Deleting instances: foobar/
    expect(deployment_deletion_output).to include('Succeeded')
    # puts bosh_runner.run('delete deployment simple', failure_expected: true)

    # Stemcells and releases remain after deletion of deployment
    expect(current_sandbox.cpi.all_stemcells.count).to eq 1
    expect(bosh_runner.run('releases')).to include('1 releases')

    expect(current_sandbox.cpi.vm_cids.count).to eq 0
    expect(current_sandbox.cpi.disk_cids.count).to eq 0
    expect(current_sandbox.cpi.all_ips.count).to eq 0
    expect(current_sandbox.cpi.all_snapshots.count).to eq 0

    #deployments
    expect(bosh_runner.run('deployments', failure_expected: true)).to include('0 deployments')
  end
end
