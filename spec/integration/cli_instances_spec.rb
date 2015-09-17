require 'spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'check output for BOSH INSTANCES' do
    target_and_login

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['availability_zones'] = [
      {'name' => 'zone-1', 'cloud_properties' => {}},
      {'name' => 'zone-2', 'cloud_properties' => {}},
      {'name' => 'zone-3', 'cloud_properties' => {}},
    ]
    cloud_config_hash['networks'].first['subnets'] = [
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1', '192.168.1.2'],
        'static' => ['192.168.1.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'availability_zone' => 'zone-1',
      },
      {
        'range' => '192.168.2.0/24',
        'gateway' => '192.168.2.1',
        'dns' => ['192.168.2.1', '192.168.2.2'],
        'static' => ['192.168.2.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'availability_zone' => 'zone-2',
      },
      {
        'range' => '192.168.3.0/24',
        'gateway' => '192.168.3.1',
        'dns' => ['192.168.3.1', '192.168.3.2'],
        'static' => ['192.168.3.10'],
        'reserved' => [],
        'cloud_properties' => {},
        'availability_zone' => 'zone-3',
      }
    ]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['availability_zones'] = ['zone-1', 'zone-2', 'zone-3']
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    output = bosh_runner.run('instances --details')

    output = scrub_random_ids(output)
    expect(output).to include('VM CID')
    expect(output).to include('Disk CID')
    expect(output).to include('Agent ID')
    expect(output).to include('Resurrection')

    output = bosh_runner.run('instances --dns')
    expect(scrub_random_ids(output)).to include(<<INSTANCES)
+--------------------------------------------------+---------+--------+---------------+-------------+------------------------+
| Instance                                         | State   | AZ     | Resource Pool | IPs         | DNS A records          |
+--------------------------------------------------+---------+--------+---------------+-------------+------------------------+
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0) | running | zone-1 | a             | 192.168.1.2 | 0.foobar.a.simple.bosh |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)  | running | zone-2 | a             | 192.168.2.2 | 1.foobar.a.simple.bosh |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)  | running | zone-3 | a             | 192.168.3.2 | 2.foobar.a.simple.bosh |
+--------------------------------------------------+---------+--------+---------------+-------------+------------------------+

(*) Bootstrap node
INSTANCES

    output = bosh_runner.run('instances --vitals')

    output = scrub_random_ids(output)
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

    output = bosh_runner.run('instances')
    expect(scrub_random_ids(output)).to include(<<INSTANCES)
+--------------------------------------------------+---------+--------+---------------+-------------+
| Instance                                         | State   | AZ     | Resource Pool | IPs         |
+--------------------------------------------------+---------+--------+---------------+-------------+
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0) | running | zone-1 | a             | 192.168.1.2 |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)  | running | zone-2 | a             | 192.168.2.2 |
| foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)  | running | zone-3 | a             | 192.168.3.2 |
+--------------------------------------------------+---------+--------+---------------+-------------+

(*) Bootstrap node
INSTANCES

  end
end
