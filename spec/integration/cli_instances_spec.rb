require 'spec_helper'

describe 'cli: instances', type: :integration do
  with_reset_sandbox_before_each

  it 'displays instances in a deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    deploy_from_scratch(manifest_hash: manifest_hash)

    output = bosh_runner.run('instances')
    expect(output).to match_output %(
      +----------+---------+---------------+-------------+
      | Instance | State   | Resource Pool | IPs         |
      +----------+---------+---------------+-------------+
      | foobar/0 | running | a             | 192.168.1.5 |
      | foobar/1 | running | a             | 192.168.1.6 |
      | foobar/2 | running | a             | 192.168.1.7 |
      +----------+---------+---------------+-------------+
    )
  end

  it 'should return instances --vitals' do
    deploy_from_scratch
    vitals = director.instances_vitals[0]

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

  context 'with the --ps flag' do
    it 'displays instance processes' do
      deploy_from_scratch
      output = bosh_runner.run('instances --ps')
      expect(output).to match_output %(
        +-------------+---------+---------------+-------------+
        | Instance    | State   | Resource Pool | IPs         |
        +-------------+---------+---------------+-------------+
        | foobar/0    | running | a             | 192.168.1.5 |
        |   process-1 | running |               |             |
        |   process-2 | running |               |             |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
        | foobar/1    | running | a             | 192.168.1.6 |
        |   process-1 | running |               |             |
        |   process-2 | running |               |             |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
        | foobar/2    | running | a             | 192.168.1.7 |
        |   process-1 | running |               |             |
        |   process-2 | running |               |             |
        |   process-3 | failing |               |             |
        +-------------+---------+---------------+-------------+
      )
    end
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
end
