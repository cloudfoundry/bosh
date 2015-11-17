require 'spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'displays instances in a deployment', dns: true do
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

    output = bosh_runner.run('instances --details')

    output = scrub_random_ids(output)
    expect(output).to include('VM CID')
    expect(output).to include('Disk CID')
    expect(output).to include('Agent ID')
    expect(output).to include('Resurrection')

    output = bosh_runner.run('instances')
    expect(scrub_random_ids(output)).to match_output %(
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | Instance                                         | State   | AZ     | Resource Pool | IPs         |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)* | running | zone-1 | a             | 192.168.1.2 |
      | foobar/1 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-2 | a             | 192.168.2.2 |
      | foobar/2 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-3 | a             | 192.168.3.2 |
      +--------------------------------------------------+---------+--------+---------------+-------------+

      (*) Bootstrap node
    )

    output = bosh_runner.run('instances --dns')
    expect(scrub_random_ids(output)).to match_output %(
      +--------------------------------------------------+---------+--------+---------------+-------------+-----------------------------------------------------------+
      | Instance                                         | State   | AZ     | Resource Pool | IPs         | DNS A records                                             |
      +--------------------------------------------------+---------+--------+---------------+-------------+-----------------------------------------------------------+
      | foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)* | running | zone-1 | a             | 192.168.1.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
      |                                                  |         |        |               |             | 0.foobar.a.simple.bosh                                    |
      | foobar/1 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-2 | a             | 192.168.2.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
      |                                                  |         |        |               |             | 1.foobar.a.simple.bosh                                    |
      | foobar/2 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-3 | a             | 192.168.3.2 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh |
      |                                                  |         |        |               |             | 2.foobar.a.simple.bosh                                    |
      +--------------------------------------------------+---------+--------+---------------+-------------+-----------------------------------------------------------+

      (*) Bootstrap node
    )

    output = bosh_runner.run('instances --ps')
    expect(scrub_random_ids(output)).to match_output %(
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | Instance                                         | State   | AZ     | Resource Pool | IPs         |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)* | running | zone-1 | a             | 192.168.1.2 |
      |   process-1                                      | running |        |               |             |
      |   process-2                                      | running |        |               |             |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/1 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-2 | a             | 192.168.2.2 |
      |   process-1                                      | running |        |               |             |
      |   process-2                                      | running |        |               |             |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/2 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-3 | a             | 192.168.3.2 |
      |   process-1                                      | running |        |               |             |
      |   process-2                                      | running |        |               |             |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
    )

    output = bosh_runner.run('instances --ps --failing')
    expect(scrub_random_ids(output)).to match_output %(
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | Instance                                         | State   | AZ     | Resource Pool | IPs         |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)* | running | zone-1 | a             | 192.168.1.2 |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/1 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-2 | a             | 192.168.2.2 |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
      | foobar/2 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)  | running | zone-3 | a             | 192.168.3.2 |
      |   process-3                                      | failing |        |               |             |
      +--------------------------------------------------+---------+--------+---------------+-------------+
    )
  end

  it 'should return instances --vitals' do
    deploy_from_scratch

    expect(vitals[:cpu_user_sys_wait]).to match /\d+\.?\d*[%], \d+\.?\d*[%], \d+\.?\d*[%]/

    expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
    expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/

    expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
    expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

    # persistent disk was not deployed
    expect(vitals[:persistent_disk_usage]).to match /n\/a/
  end

  context 'with the --failing flag' do
    it 'filters out non-failing instances' do
      deploy_from_scratch
      expect(bosh_runner.run('instances --failing'))
        .to match /No failing instances/
    end
  end

  context 'with the --failing and --ps flags' do
    it 'filters out non-failing processes' do
      deploy_from_scratch
      instances_ps = bosh_runner.run('instances --ps --failing')
      expect(instances_ps).to match_output %(
        +-------------+---------+---------------+-------------+
        | Instance    | State   | Resource Pool | IPs         |
        +-------------+---------+---------------+-------------+
        | foobar/0    | running | a             | 192.168.1.5 |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
        | foobar/1    | running | a             | 192.168.1.6 |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
        | foobar/2    | running | a             | 192.168.1.7 |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
      )
    end
  end

  context 'with the --vitals and --ps flags' do
    it 'display instances and processes' do
      deploy_from_scratch
      vitals = director.instances_ps_vitals[0]

      expect(vitals[:uptime]).to be_empty
      expect(vitals[:cpu]).to be_empty
      expect(vitals[:cpu_user_sys_wait]).to match /\d+\.?\d*[%], \d+\.?\d*[%], \d+\.?\d*[%]/

      expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
      expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/

      expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
      expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

      # persistent disk was not deployed
      expect(vitals[:persistent_disk_usage]).to match /n\/a/

      vitals = director.instances_ps_vitals[1]

      expect(vitals[:uptime]).to match /\d+d \d+h \d+m \d+s/
      expect(vitals[:cpu_user_sys_wait]).to be_empty
      expect(vitals[:cpu]).to match /\d+%/
      expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
    end

    it 'filters out non-failing processes' do
      deploy_from_scratch
      vitals = director.instances_ps_vitals_failing[0]

      expect(vitals[:uptime]).to be_empty
      expect(vitals[:cpu]).to be_empty
      expect(vitals[:cpu_user_sys_wait]).to match /\d+\.?\d*[%], \d+\.?\d*[%], \d+\.?\d*[%]/

      expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
      expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/

      expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
      expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

      # persistent disk was not deployed
      expect(vitals[:persistent_disk_usage]).to match /n\/a/

      vitals = director.instances_ps_vitals_failing[1]

      expect(vitals[:instance]).to eq('process-3')
      expect(vitals[:uptime]).to match /\d+d \d+h \d+m \d+s/
      expect(vitals[:cpu_user_sys_wait]).to be_empty
      expect(vitals[:cpu]).to match /\d+%/
      expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
    end
  end
end
