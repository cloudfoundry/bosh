require 'spec_helper'

describe Bosh::Monitor::Events::Heartbeat do
  let(:timestamp) { 1320196099  }

  let(:heartbeat) { make_heartbeat(timestamp: timestamp) }

  context 'validations' do
    it 'requires id' do
      expect(make_heartbeat(id: nil)).not_to be_valid
    end

    it 'requires timestamp' do
      expect(make_heartbeat(timestamp: nil)).not_to be_valid
    end

    it 'supports attributes validation' do
      bad_heartbeat = make_heartbeat(id: nil, timestamp: nil)
      expect(bad_heartbeat).not_to be_valid
      expect(bad_heartbeat.error_message).to eq('id is missing, timestamp is missing')
    end

    it 'should be valid' do
      expect(heartbeat).to be_valid
      expect(heartbeat.kind).to eq(:heartbeat)
    end
  end

  it 'has short description' do
    expect(heartbeat.short_description)
      .to eq('Heartbeat from mysql_node/instance_id_abc (agent_id=deadbeef index=0) @ 2011-11-02 01:08:19 UTC')
    expect(make_heartbeat(index: nil, timestamp: timestamp).short_description)
      .to eq('Heartbeat from mysql_node/instance_id_abc (agent_id=deadbeef) @ 2011-11-02 01:08:19 UTC')
  end

  it 'has hash representation' do
    expect(heartbeat.to_hash).to eq(
      kind: 'heartbeat',
      id: 1,
      timestamp: timestamp,
      deployment: 'oleg-cloud',
      agent_id: 'deadbeef',
      instance_id: 'instance_id_abc',
      job: 'mysql_node',
      index: '0',
      job_state: 'running',
      vitals: {
        'load' => [0.2, 0.3, 0.6],
        'cpu' => { 'user' => 22.3, 'sys' => 23.4, 'wait' => 33.22 },
        'mem' => { 'percent' => 32.2, 'kb' => 512031 },
        'swap' => { 'percent' => 32.6, 'kb' => 231312 },
        'disk' => {
          'system' => { 'percent' => 74, 'inode_percent' => 68 },
          'ephemeral' => { 'percent' => 33, 'inode_percent' => 74 },
          'persistent' => { 'percent' => 97, 'inode_percent' => 10 },
        },
      },
      teams: %w[ateam bteam],
      number_of_processes: 5,
      metrics: [
        { name: 'system.load.1m', value: '0.2', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.cpu.user', value: '22.3', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.cpu.sys', value: '23.4', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.cpu.wait', value: '33.22', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.mem.percent', value: '32.2', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.mem.kb', value: '512031', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.swap.percent', value: '32.6', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.swap.kb', value: '231312', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.system.percent', value: '74', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.system.inode_percent', value: '68', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.ephemeral.percent', value: '33', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.ephemeral.inode_percent', value: '74', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.persistent.percent', value: '97', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.disk.persistent.inode_percent', value: '10', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
        { name: 'system.healthy', value: '1', timestamp: 1320196099, tags: { 'job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc' } },
      ],
    )
  end

  it 'has plain text representation' do
    hb = heartbeat
    expect(hb.to_plain_text).to eq(hb.short_description)
  end

  it 'has json representation' do
    hb = heartbeat
    expect(hb.to_json).to eq(JSON.dump(hb.to_hash))
  end

  it 'has string representation' do
    hb = heartbeat
    expect(hb.to_s).to eq(hb.short_description)
  end

  it 'has metrics' do
    hb = heartbeat
    metrics = hb.metrics.each_with_object({}) do |m, h|
      expect(m).to be_kind_of(Bosh::Monitor::Metric)
      expect(m.tags).to eq('job' => 'mysql_node', 'index' => '0', 'id' => 'instance_id_abc')
      h[m.name] = m.value
    end

    expect(metrics['system.load.1m']).to eq(0.2)
    expect(metrics['system.cpu.user']).to eq(22.3)
    expect(metrics['system.cpu.sys']).to eq(23.4)
    expect(metrics['system.cpu.wait']).to eq(33.22)
    expect(metrics['system.mem.percent']).to eq(32.2)
    expect(metrics['system.mem.kb']).to eq(512031)
    expect(metrics['system.swap.percent']).to eq(32.6)
    expect(metrics['system.swap.kb']).to eq(231312)
    expect(metrics['system.disk.system.percent']).to eq(74)
    expect(metrics['system.disk.system.inode_percent']).to eq(68)
    expect(metrics['system.disk.ephemeral.percent']).to eq(33)
    expect(metrics['system.disk.ephemeral.inode_percent']).to eq(74)
    expect(metrics['system.disk.persistent.percent']).to eq(97)
    expect(metrics['system.disk.persistent.inode_percent']).to eq(10)
    expect(metrics['system.healthy']).to eq(1)
  end
end
