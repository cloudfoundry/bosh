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
    id = data[-1]["ID"]
    event_output =  bosh_runner.run("event #{id}")
    expect(event_output.split.join(" ")).to include("ID #{id}")

    data = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    stable_data = get_details(data, ['ID', 'Time', 'User', 'Task ID'])
    flexible_data = get_details(data, [ 'Action', 'Object Type', 'Object ID', 'Deployment', 'Instance', 'Context', 'Error'])

    expect(stable_data).to all(include('Time' => /xxx xxx xx xx:xx:xx UTC xxxx|^$/))
    expect(stable_data).to all(include('User' => /test|^$/))
    expect(stable_data).to all(include('Task ID' => /[0-9]{1,3}|-|^$/))
    expect(stable_data).to all(include('ID' => /[0-9]{1,3} <- [0-9]{1,3}|[0-9]{1,3}|^$/))

    expect(flexible_data).to contain_exactly(
      {'Action' => 'delete', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => '', 'Error' => ''},
      {'Action' => 'update', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1", 'Error' => "'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update. Review logs for failed jobs: process-3"},
      {'Action' => 'start', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => "'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' is not running after update. Review logs for failed jobs: process-3"},
      {'Action' => 'start', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'update', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore: {}", 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'disk', 'Object ID' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'disk', 'Object ID' => '', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'instance', 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'vm', 'Object ID' => '', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'delete', 'Object Type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'vm', 'Object ID' => /[0-9]{1,5}/, 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'vm', 'Object ID' => '', 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'instance', 'Object ID' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'compilation-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '', 'Error' => ''},
      {'Action' => 'create', 'Object Type' => 'deployment', 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => '', 'Error' => ''},
      {'Action' => 'update', 'Object Type' => 'runtime-config', 'Object ID' => '', 'Deployment' => '', 'Instance' => '', 'Context' => '', 'Error' => ''},
      {'Action' => 'update', 'Object Type' => 'cloud-config', 'Object ID' => '', 'Deployment' => '', 'Instance' => '', 'Context' => '', 'Error' => ''},
    )

    instance_name = parse_first_instance_name(output)
    output = bosh_runner.run("events --task 6 --instance #{instance_name} --action delete", deployment_name: 'simple', json: true)
    data = table(output)
    columns = ['Action', 'Object Type', 'Deployment', 'Instance', 'Task ID']
    expect(get_details(data, columns)).to contain_exactly(
        {'Action' => 'delete', 'Object Type' => 'instance', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name},
        {'Action' => 'delete', 'Object Type' => 'disk', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name},
        {'Action' => 'delete', 'Object Type' => 'disk', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name},
        {'Action' => 'delete', 'Object Type' => 'vm', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name},
        {'Action' => 'delete', 'Object Type' => 'vm', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name},
        {'Action' => 'delete', 'Object Type' => 'instance', 'Task ID' => '6', 'Deployment' => 'simple', 'Instance' => instance_name})
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
