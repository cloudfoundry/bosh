require 'spec_helper'

describe 'cli: vms', type: :integration do
  with_reset_sandbox_before_each

  it 'should return vm --vitals' do
    deploy_from_scratch
    vitals = director.vms_vitals[0]

    expect(vitals[:cpu_user]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_sys]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_wait]).to match /\d+\.?\d*[%]/

    expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
    expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/

    expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
    expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

    # persistent disk was not deployed
    expect(vitals[:persistent_disk_usage]).to match /n\/a/
  end

  it 'should return ips for legacy deployments' do
    target_and_login

    manifest = Bosh::Spec::Deployments.legacy_manifest
    manifest['networks'] << {
          'name' => 'b',
          'subnets' => [{
              'range' => '192.168.2.0/24',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => ['192.168.2.10'],
              'reserved' => [],
              'cloud_properties' => {},
          }],
      }
    manifest['jobs'].first['networks'] << {'name' => 'b', 'default' => ['dns', 'gateway']}
    manifest['jobs'].first['instances'] = 1

    deploy_from_scratch(manifest_hash: manifest)

    expect(scrub_random_ids(bosh_runner.run('vms'))).to match_output %(
        +-------------------------------------------------+---------+-----+---------+-------------+
        | VM                                              | State   | AZ  | VM Type | IPs         |
        +-------------------------------------------------+---------+-----+---------+-------------+
        | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) | running | n/a | a       | 192.168.1.2 |
        |                                                 |         |     |         | 192.168.2.2 |
        +-------------------------------------------------+---------+-----+---------+-------------+
        )
  end

  it 'should return az with vms' do
    target_and_login

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

    expect(scrub_random_ids(bosh_runner.run('vms'))).to include(<<VMS)
+-------------------------------------------------+---------+--------+---------+-------------+
| VM                                              | State   | AZ     | VM Type | IPs         |
+-------------------------------------------------+---------+--------+---------+-------------+
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) | running | zone-1 | a       | 192.168.1.2 |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1) | running | zone-2 | a       | 192.168.2.2 |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2) | running | zone-3 | a       | 192.168.3.2 |
+-------------------------------------------------+---------+--------+---------+-------------+
VMS
    output = bosh_runner.run('vms --details')

    output = scrub_random_ids(output)
    expect(output).to include('VM')
    expect(output).to include('State')
    expect(output).to include('AZ')
    expect(output).to include('VM Type')
    expect(output).to include('IPs')
    expect(output).to include('CID')
    expect(output).to include('Agent ID')
    expect(output).to include('Resurrection')
    expect(output).to include('Ignore')

    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)')
    expect(output).to include('zone-1')
    expect(output).to include('zone-2')
    expect(output).to include('zone-3')
    expect(output.scan(/\| xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \| active       \| false  \|/).count).to eq(3)

    expect(scrub_random_ids(bosh_runner.run('vms --dns'))).to include(<<VMS)
+-------------------------------------------------+---------+--------+---------+-------------+-----------------------------------------------------------+
| VM                                              | State   | AZ     | VM Type | IPs         | DNS A records                                             |
+-------------------------------------------------+---------+--------+---------+-------------+-----------------------------------------------------------+
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) | running | zone-1 | a       | 192.168.1.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
|                                                 |         |        |         |             | 0.foobar.a.simple.bosh                                    |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1) | running | zone-2 | a       | 192.168.2.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
|                                                 |         |        |         |             | 1.foobar.a.simple.bosh                                    |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2) | running | zone-3 | a       | 192.168.3.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
|                                                 |         |        |         |             | 2.foobar.a.simple.bosh                                    |
+-------------------------------------------------+---------+--------+---------+-------------+-----------------------------------------------------------+
VMS

    output = bosh_runner.run('vms --vitals')

    output = scrub_random_ids(output)
    expect(output).to include('VM')
    expect(output).to include('State')
    expect(output).to include('AZ')
    expect(output).to include('VM Type')
    expect(output).to include('IPs')
    expect(output).to include('Load')
    expect(output).to include('User')
    expect(output).to include('Sys')
    expect(output).to include('Wait')
    expect(output).to include('Memory Usage')
    expect(output).to include('Swap Usage')
    expect(output).to include('System')
    expect(output).to include('Disk Usage')
    expect(output).to include('Ephemeral')
    expect(output).to include('Persistent')

    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
    expect(output).to include('foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)')
    expect(output).to include('zone-1')
    expect(output).to include('zone-2')
    expect(output).to include('zone-3')

  end
end
