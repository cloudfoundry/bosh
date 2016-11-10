require_relative '../spec_helper'

describe 'restart job', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) {
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] << {
        'name' => 'another-job',
        'template' => 'foobar',
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
    }
    manifest_hash['jobs'].first['instances'] = 2
    manifest_hash
  }

  it 'restarts a job instance / job / all jobs' do
    deploy_from_scratch(manifest_hash: manifest_hash)

    vm_before_with_index_1 = director.vms.find{ |vm| vm.index == '1' }
    instance_uuid = vm_before_with_index_1.instance_uuid

    expect(bosh_runner.run('restart foobar/0', deployment_name: 'simple')).to match /Updating instance foobar: foobar.* \(0\)/
    expect(bosh_runner.run("restart foobar/#{instance_uuid}", deployment_name: 'simple')).to match /Updating instance foobar: foobar\/#{instance_uuid} \(\d\)/
    output = bosh_runner.run('restart foobar', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar\/.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar\/.* \(1\)/
    output = bosh_runner.run('restart', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar\/.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar\/.* \(1\)/
    expect(output).to match /Updating instance another-job: another-job\/.* \(0\)/

    output = bosh_runner.run('events', json: true)
    events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    expect(events).to include(
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object Type' => 'deployment', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1"},
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'restart', 'Object Type' => 'instance', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => ''},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'restart', 'Object Type' => 'instance', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => ''},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object Type' => 'deployment', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => ''}
    )
  end
end
