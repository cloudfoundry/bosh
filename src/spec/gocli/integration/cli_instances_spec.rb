require_relative '../spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'displays instances in a deployment' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [
      {'name' => 'zone-1', 'cloud_properties' => {}},
      {'name' => 'zone-2', 'cloud_properties' => {}},
      {'name' => 'zone-3', 'cloud_properties' => {}},
    ]
    cloud_config_hash['compilation']['az'] = 'zone-1'
    cloud_config_hash['networks'].first['subnets'] = [
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1', '192.168.1.2'],
        'static' => ['192.168.1.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'az' => 'zone-1',
      },
      {
        'range' => '192.168.2.0/24',
        'gateway' => '192.168.2.1',
        'dns' => ['192.168.2.1', '192.168.2.2'],
        'static' => ['192.168.2.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'az' => 'zone-2',
      },
      {
        'range' => '192.168.3.0/24',
        'gateway' => '192.168.3.1',
        'dns' => ['192.168.3.1', '192.168.3.2'],
        'static' => ['192.168.3.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'az' => 'zone-3',
      }
    ]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['azs'] = ['zone-1', 'zone-2', 'zone-3']
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    output = bosh_runner.run('instances --details', json: true, deployment_name: 'simple')

    output = scrub_random_ids(table(output))
    expect(output).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2', 'state' => 'started', 'vm_cid' => /\d+/, 'vm_type' => 'a', 'disk_cids' => '', 'agent_id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'index' => '0', 'resurrection_paused'=> 'false', 'bootstrap' => 'true', 'ignore' => 'false'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2', 'state' => 'started', 'vm_cid' => /\d+/, 'vm_type' => 'a', 'disk_cids' => '', 'agent_id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'index' => '1', 'resurrection_paused'=> 'false', 'bootstrap' => 'false', 'ignore' => 'false'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2', 'state' => 'started', 'vm_cid' => /\d+/, 'vm_type' => 'a', 'disk_cids' => '', 'agent_id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'index' => '2', 'resurrection_paused'=> 'false', 'bootstrap' => 'false', 'ignore' => 'false'},
    )

    first_row = output.first
    expect(first_row).to have_key('vm_cid')
    expect(first_row).to have_key('disk_cids')
    expect(first_row).to have_key('agent_id')
    expect(first_row).to have_key('resurrection_paused')
    expect(first_row).to have_key('ignore')
    expect(output.length).to eq(3)

    output = bosh_runner.run('instances --dns', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n0.foobar.a.simple.bosh"},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n1.foobar.a.simple.bosh"},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n2.foobar.a.simple.bosh"},
    )

    output = bosh_runner.run('instances --ps', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-1', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-2', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-1', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-2', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-1', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-2', 'process_state' => 'running', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
    )

    output = bosh_runner.run('instances --ps --failing', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => '', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process' => 'process-3', 'process_state' => 'failing', 'az' => '', 'ips' => ''},
    )
  end

  it 'should return instances --vitals' do
    deploy_from_scratch
    vitals = director.instances_ps_vitals[0]

    print vitals
    print vitals.keys

    expect(vitals[:cpu_user]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_sys]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_wait]).to match /\d+\.?\d*[%]/

    expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d* \w+\)/
    expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d* \w+\)/

    expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
    expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

    # persistent disk was not deployed
    expect(vitals[:persistent_disk_usage]).to eq('')
  end
end
