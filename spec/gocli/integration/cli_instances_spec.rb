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
    first_row = output.first
    expect(first_row).to have_key('VM CID')
    expect(first_row).to have_key('Disk CIDs')
    expect(first_row).to have_key('Agent ID')
    expect(first_row).to have_key("Resurrection\nPaused")
    expect(first_row).to have_key('Ignore')
    expect(output.length).to eq(3)

    output = bosh_runner.run('instances --dns', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process State' => 'running', 'AZ' => 'zone-1', 'IPs' => '192.168.1.2', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n0.foobar.a.simple.bosh"},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process State' => 'running', 'AZ' => 'zone-2', 'IPs' => '192.168.2.2', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n1.foobar.a.simple.bosh"},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process State' => 'running', 'AZ' => 'zone-3', 'IPs' => '192.168.3.2', 'DNS A Records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n2.foobar.a.simple.bosh"},
    )

    output = bosh_runner.run('instances --ps', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-1', 'IPs' => '192.168.1.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => 'process-1', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => 'process-2', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-2', 'IPs' => '192.168.2.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => 'process-1', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => 'process-2', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-3', 'IPs' => '192.168.3.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => 'process-1', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => 'process-2', 'Process State' => "running", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
    )

    output = bosh_runner.run('instances --ps --failing', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-1', 'IPs' => '192.168.1.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* (0)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-2', 'IPs' => '192.168.2.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => '', 'Process State' => "running", 'AZ' => 'zone-3', 'IPs' => '192.168.3.2'},
      {'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)', 'Process' => 'process-3', 'Process State' => "failing", 'AZ' => '', 'IPs' => ''},
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
    expect(vitals[:persistent_disk_usage]).to eq("")
  end
end
