require_relative '../spec_helper'

describe 'cli: events', type: :integration do
  with_reset_sandbox_before_each

  it 'displays deployment events' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['persistent_disk_pool'] = 'disk_a'
    manifest_hash['jobs'][0]['instances'] = 1
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    disk_pool = Bosh::Spec::Deployments.disk_pool
    cloud_config['disk_pools'] = [disk_pool]
    cloud_config['compilation']['reuse_compilation_vms'] = true
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, runtime_config_hash: {
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}]
    })

    director.instance('foobar', '0').fail_job
    deploy(manifest_hash: manifest_hash, deployment_name: 'simple', failure_expected: true)

    bosh_runner.run('delete-deployment', deployment_name: 'simple')
    output = bosh_runner.run('events', json: true)

    data = table(output)
    id = data[-1]["id"]
    event_output =  bosh_runner.run("event #{id}")
    expect(event_output.split.join(" ")).to include("ID #{id}")

    data = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    stable_data = get_details(data, ['id', 'time', 'user', 'task_id'])
    flexible_data = get_details(data, [ 'action', 'object_type', 'object_name', 'deployment', 'instance', 'context', 'error'])

    expect(stable_data).to all(include('time' => /xxx xxx xx xx:xx:xx UTC xxxx|^$/))
    expect(stable_data).to all(include('user' => /test|_director|^$/))
    expect(stable_data).to all(include('task_id' => /[0-9]{1,3}|-|^$/))
    expect(stable_data).to all(include('id' => /[0-9]{1,3} <- [0-9]{1,3}|[0-9]{1,3}|^$/))

    expect(flexible_data).to contain_exactly(
      {'action' => 'start', 'object_type' => 'worker', 'object_name' => 'worker_0', 'deployment' => '', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'start', 'object_type' => 'worker', 'object_name' => 'worker_1', 'deployment' => '', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'start', 'object_type' => 'worker', 'object_name' => 'worker_2', 'deployment' => '', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'orphan', 'object_type' => 'disk', 'object_name' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'orphan', 'object_type' => 'disk', 'object_name' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'update', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1", 'error' => "'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)' is not running after update. Review logs for failed jobs: process-3"},
      {'action' => 'start', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => "'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)' is not running after update. Review logs for failed jobs: process-3"},
      {'action' => 'start', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'update', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore: {}", 'error' => ''},
      {'action' => 'create', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'disk', 'object_name' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'disk', 'object_name' => '', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'instance', 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'vm', 'object_name' => '', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'instance', 'object_name' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'delete', 'object_type' => 'instance', 'object_name' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'instance', 'object_name' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'vm', 'object_name' => /[0-9]{1,5}/, 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'vm', 'object_name' => '', 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'instance', 'object_name' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'action' => 'create', 'object_type' => 'deployment', 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'update', 'object_type' => 'runtime-config', 'object_name' => 'default', 'deployment' => '', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'update', 'object_type' => 'cloud-config', 'object_name' => 'default', 'deployment' => '', 'instance' => '', 'context' => '', 'error' => ''},
      {'action' => 'start', 'object_type' => 'director', 'object_name' => 'deadbeef', 'deployment' => '', 'instance' => '', 'context' => 'version: 0.0.0',  'error' => ''},
      {'action' => 'release', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' =>'lock:deployment:simple', 'object_type'=> 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' =>'lock:deployment:simple', 'object_type'=> 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' =>'', 'object_name' =>'lock:deployment:simple', 'object_type'=> 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => '', 'error' =>'', 'instance' =>'', 'object_name' =>'lock:release:bosh-release', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => '', 'error' =>'', 'instance' =>'', 'object_name' =>'lock:release:bosh-release', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:deployment:simple', 'object_type' => 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:deployment:simple', 'object_type' => 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:compile:3:toronto-os/1', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:compile:3:toronto-os/1', 'object_type' => 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:compile:8:toronto-os/1', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:compile:8:toronto-os/1', 'object_type' => 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => '', 'error' => '', 'instance' => '', 'object_name' => 'lock:release:bosh-release', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => '', 'error' => '', 'instance' => '', 'object_name' => 'lock:release:bosh-release', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => 'simple', 'error' => '', 'instance' => '', 'object_name' => 'lock:deployment:simple', 'object_type' => 'lock'},
      {'action' => 'release', 'context' => '', 'deployment' => '', 'error' => '', 'instance' => '', 'object_name' => 'lock:release:bosh-release', 'object_type' => 'lock'},
      {'action' => 'acquire', 'context' => '', 'deployment' => '', 'error' => '', 'instance' => '', 'object_name' => 'lock:release:bosh-release', 'object_type' => 'lock'},
    )

    instance_name = parse_first_instance_name(output)
    output = bosh_runner.run("events --task 6 --instance #{instance_name} --action delete", deployment_name: 'simple', json: true)
    data = table(output)
    columns = ['action', 'object_type', 'deployment', 'instance', 'task_id']
    expect(get_details(data, columns)).to contain_exactly(
        {'action' => 'delete', 'object_type' => 'instance', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name},
        {'action' => 'delete', 'object_type' => 'vm', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name},
        {'action' => 'delete', 'object_type' => 'vm', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name},
        {'action' => 'delete', 'object_type' => 'instance', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name})

    output = bosh_runner.run("events --task 6 --instance #{instance_name} --action orphan", deployment_name: 'simple', json: true)
    data = table(output)
    columns = ['action', 'object_type', 'deployment', 'instance', 'task_id']
    expect(get_details(data, columns)).to contain_exactly(
        {'action' => 'orphan', 'object_type' => 'disk', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name},
        {'action' => 'orphan', 'object_type' => 'disk', 'task_id' => '6', 'deployment' => 'simple', 'instance' => instance_name})
  end

  def get_details(table, keys)
    table.map do |hash|
      hash.select do |key, _|
        keys.include? key
      end
    end
  end

  def parse_first_instance_name(output)
    regexp = %r{
      foobar\/([0-9a-f]{8}-[0-9a-f-]{27})\b
    }x
    regexp.match(output)[0]
  end
end
