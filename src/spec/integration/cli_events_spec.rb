require 'spec_helper'

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

    director.vm('foobar', '0').fail_job
    deploy(failure_expected: true)

    bosh_runner.run('delete deployment simple')
    output = bosh_runner.run('events')

    data = Support::TableHelpers::Parser.new(scrub_event_time(scrub_random_cids(scrub_random_ids(output)))).data
    stable_data = get_details(data, ['ID', 'Time', 'User', 'Task'])
    flexible_data = get_details(data, [ 'Action', 'Object type', 'Object ID', 'Dep', 'Inst', 'Context'])

    expect(stable_data).to all(include('Time' => /xxx xxx xx xx:xx:xx UTC xxxx|^$/))
    expect(stable_data).to all(include('User' => /test|_director|^$/))
    expect(stable_data).to all(include('Task' => /[0-9]{1,3}|-|^$/))
    expect(stable_data).to all(include('ID' => /[0-9]{1,3} <- [0-9]{1,3}|[0-9]{1,3}|^$/))

    expect(flexible_data).to contain_exactly(
      {'Action' => 'start', 'Object type' => 'worker', 'Object ID' => 'worker_0', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'start', 'Object type' => 'worker', 'Object ID' => 'worker_1', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'start', 'Object type' => 'worker', 'Object ID' => 'worker_2', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'orphan', 'Object type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'orphan', 'Object type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'update', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => "error: 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)' is not running after update....,"},
      {'Action' => '', 'Object type' => '', 'Object ID' => '', 'Dep' => '', 'Inst' => '', 'Context' => 'before: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]},'},
      {'Action' => '', 'Object type' => '', 'Object ID' => '', 'Dep' => '', 'Inst' => '', 'Context' => 'after: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]}'},
      {'Action' => 'start', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => "error: 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)' is not running after update...."},
      {'Action' => 'start', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'update', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => 'before: {},'},
      {'Action' => '', 'Object type' => '', 'Object ID' => '', 'Dep' => '', 'Inst' => '', 'Context' => 'after: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]}'},
      {'Action' => 'create', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'disk', 'Object ID' => '-', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'vm', 'Object ID' => '-', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'delete', 'Object type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'vm', 'Object ID' => '-', 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'Action' => 'create', 'Object type' => 'deployment', 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'update', 'Object type' => 'runtime-config', 'Object ID' => '-', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'update', 'Object type' => 'cloud-config', 'Object ID' => '-', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'start', 'Object type' => 'director', 'Object ID' => 'deadbeef', 'Dep' => '-', 'Inst' => '-', 'Context' => 'version: 0.0.0'},
      {'Action' => 'release', 'Object type'=> 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type'=> 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type'=> 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:compile:3:toronto-os/1', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:compile:3:toronto-os/1', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:compile:8:toronto-os/1', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:compile:8:toronto-os/1', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-','Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-','Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:deployment:simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'Action' => 'release', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-','Inst' => '-', 'Context' => '-'},
      {'Action' => 'acquire', 'Object type' => 'lock', 'Object ID' => 'lock:release:bosh-release', 'Dep' => '-','Inst' => '-', 'Context' => '-'},
    )

    instance_name = parse_first_instance_name(output)
    output = bosh_runner.run("events --deployment simple --task 6 --instance #{instance_name}")
    data = Support::TableHelpers::Parser.new(output).data
    columns = ['Action', 'Object type', 'Dep', 'Inst', 'Task']
    expect(get_details(data, columns)).to contain_exactly(
        {'Action' => 'delete', 'Object type' => 'instance', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name},
        {'Action' => 'orphan', 'Object type' => 'disk', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name},
        {'Action' => 'orphan', 'Object type' => 'disk', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name},
        {'Action' => 'delete', 'Object type' => 'vm', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name},
        {'Action' => 'delete', 'Object type' => 'vm', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name},
        {'Action' => 'delete', 'Object type' => 'instance', 'Task' => '6', 'Dep' => 'simple', 'Inst' => instance_name})
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
