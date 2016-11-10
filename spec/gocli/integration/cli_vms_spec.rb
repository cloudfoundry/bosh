require_relative '../spec_helper'

describe 'cli: vms', type: :integration do
  with_reset_sandbox_before_each

  it 'should return vm --vitals' do
    deploy_from_scratch
    vitals = director.vms_vitals[0]

    expect(vitals[:cpu_user]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_sys]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_wait]).to match /\d+\.?\d*[%]/

    expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d* \w+\)/
    expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d* \w+\)/

    expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
    expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

    # persistent disk was not deployed
    expect(vitals[:persistent_disk_usage]).to eq("")
  end

  it 'should return az with vms' do
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

    expect(scrub_random_ids(table(bosh_runner.run('vms', json: true, deployment_name: 'simple')))).to contain_exactly(
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process State' => 'running', 'AZ' => 'zone-1', 'IPs' => '192.168.1.2', 'VM CID' => String, 'VM Type' => 'a'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process State' => 'running', 'AZ' => 'zone-2', 'IPs' => '192.168.2.2', 'VM CID' => String, 'VM Type' => 'a'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process State' => 'running', 'AZ' => 'zone-3', 'IPs' => '192.168.3.2', 'VM CID' => String, 'VM Type' => 'a'},
    )
    output = bosh_runner.run('vms --details', json: true, deployment_name: 'simple')

    output = scrub_random_ids(table(output))
    first_row = output.first

    expect(first_row).to have_key('Instance')
    expect(first_row).to have_key('Process State')
    expect(first_row).to include('AZ')
    expect(first_row).to include('IPs')
    expect(first_row).to have_key('Disk CIDs')
    expect(first_row).to have_key('Agent ID')
    expect(first_row).to have_key("Resurrection\nPaused")
    expect(first_row).to have_key('Ignore')
    expect(output.length).to eq(3)

    output = bosh_runner.run('vms --dns', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process State' => 'running', 'AZ' => 'zone-1', 'IPs' => '192.168.1.2', 'VM CID' => String, 'VM Type' => 'a', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n0.foobar.a.simple.bosh"},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process State' => 'running', 'AZ' => 'zone-2', 'IPs' => '192.168.2.2', 'VM CID' => String, 'VM Type' => 'a', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n1.foobar.a.simple.bosh"},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process State' => 'running', 'AZ' => 'zone-3', 'IPs' => '192.168.3.2', 'VM CID' => String, 'VM Type' => 'a', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n2.foobar.a.simple.bosh"},
    )

    output = bosh_runner.run('vms --vitals', json: true, deployment_name: 'simple')

    output = scrub_random_ids(table(output))
    first_row = output.first
    expect(first_row).to include('Instance')
    expect(first_row).to include('Process State')
    expect(first_row).to include('AZ')
    expect(first_row).to include('IPs')
    expect(first_row).to include('VM CID')
    expect(first_row).to include('VM Type')
    expect(first_row).to include('Uptime')
    expect(first_row).to include("Load\n(1m, 5m, 15m)")
    expect(first_row).to include("CPU\nTotal")
    expect(first_row).to include("CPU\nUser")
    expect(first_row).to include("CPU\nSys")
    expect(first_row).to include("CPU\nWait")
    expect(first_row).to include("Memory\nUsage")
    expect(first_row).to include("Swap\nUsage")
    expect(first_row).to include("System\nDisk Usage")
    expect(first_row).to include("Ephemeral\nDisk Usage")
    expect(first_row).to include("Persistent\nDisk Usage")
    expect(output.length).to eq(3)
  end
end
