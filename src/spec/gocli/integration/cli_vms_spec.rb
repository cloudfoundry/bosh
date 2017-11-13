require_relative '../spec_helper'

describe 'cli: vms', type: :integration do
  with_reset_sandbox_before_each

  it 'should return vm --vitals' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)
    vitals = director.vms_vitals[0]

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

  it 'should return cloud_properties with vm_type cloud properties' do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'].first['cloud_properties']['flavor'] = 'some-flavor'

    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    vms = director.vms_cloud_properties
    expect(vms.map { |vm| vm[:cloud_properties]}).to eq(['flavor: some-flavor', 'flavor: some-flavor', 'flavor: some-flavor'])
  end

  it 'should return cloud_properties with calculated vm cloud properties' do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups_and_vm_resources
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    vms = director.vms_cloud_properties
    cloud_props_from_dummy_cpi = "ephemeral_disk:\n  size: 10\ninstance_type: dummy"
    expect(vms.map { |vm| vm[:cloud_properties]}).to eq([cloud_props_from_dummy_cpi, cloud_props_from_dummy_cpi, cloud_props_from_dummy_cpi])
  end

  it 'should return az with vms' do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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

    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['azs'] = ['zone-1', 'zone-2', 'zone-3']
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    expect(scrub_random_ids(table(bosh_runner.run('vms', json: true, deployment_name: 'simple')))).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2', 'vm_cid' => String, 'vm_type' => 'a'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2', 'vm_cid' => String, 'vm_type' => 'a'},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2', 'vm_cid' => String, 'vm_type' => 'a'},
    )


    output = bosh_runner.run('vms --dns', json: true, deployment_name: 'simple')
    expect(scrub_random_ids(table(output))).to contain_exactly(
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-1', 'ips' => '192.168.1.2', 'vm_cid' => String, 'vm_type' => 'a', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n0.foobar.a.simple.bosh"},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-2', 'ips' => '192.168.2.2', 'vm_cid' => String, 'vm_type' => 'a', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n1.foobar.a.simple.bosh"},
      {'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'process_state' => 'running', 'az' => 'zone-3', 'ips' => '192.168.3.2', 'vm_cid' => String, 'vm_type' => 'a', 'dns_a_records' => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.foobar.a.simple.bosh\n2.foobar.a.simple.bosh"},
    )

    output = bosh_runner.run('vms --vitals', json: true, deployment_name: 'simple')

    output = scrub_random_ids(table(output))
    first_row = output.first
    expect(first_row).to include('instance')
    expect(first_row).to include('process_state')
    expect(first_row).to include('az')
    expect(first_row).to include('ips')
    expect(first_row).to include('vm_cid')
    expect(first_row).to include('vm_type')
    expect(first_row).to include('vm_created_at')
    expect(first_row).to include('uptime')
    expect(first_row).to include('load_1m_5m_15m')
    expect(first_row).to include('cpu_total')
    expect(first_row).to include('cpu_user')
    expect(first_row).to include('cpu_sys')
    expect(first_row).to include('cpu_wait')
    expect(first_row).to include('memory_usage')
    expect(first_row).to include('swap_usage')
    expect(first_row).to include('system_disk_usage')
    expect(first_row).to include('ephemeral_disk_usage')
    expect(first_row).to include('persistent_disk_usage')
    expect(output.length).to eq(3)
  end

  it "retrieves vms from deployments in parallel" do
    manifest1 = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest1['name'] = 'simple1'
    manifest1['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar1', :instances => 2})]
    deploy_from_scratch(manifest_hash: manifest1)

    manifest2 = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest2['name'] = 'simple2'
    manifest2['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group({:name => 'foobar2', :instances => 4})]
    deploy_from_scratch(manifest_hash: manifest2)

    output = bosh_runner.run('vms --parallel 5')
    expect(output).to include('Succeeded')
    # 2 deployments must not be mixed in the output, but they can be printed in any order
    expect(output).to match(/Deployment 'simple1'\s*\n\nInstance\s+Process\s+State\s+AZ\s+IPs\s+VM\s+CID\s+VM\s+Type\s*\n(foobar1\/\w+-\w+-\w+-\w+-\w+\s+running\s+-\s+\d+.\d+.\d+.\d+\s+\d+\s+a\s*\n){2}\n2 vms/)
    expect(output).to match(/Deployment 'simple2'\s*\n\nInstance\s+Process\s+State\s+AZ\s+IPs\s+VM\s+CID\s+VM\s+Type\s*\n(foobar2\/\w+-\w+-\w+-\w+-\w+\s+running\s+-\s+\d+.\d+.\d+.\d+\s+\d+\s+a\s*\n){4}\n4 vms/)
  end
end
