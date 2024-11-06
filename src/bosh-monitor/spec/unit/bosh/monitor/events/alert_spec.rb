require 'spec_helper'

describe Bosh::Monitor::Events::Alert do
  it 'supports attributes validation' do
    expect(make_alert).to be_valid
    expect(make_alert.kind).to eq(:alert)

    expect(make_alert(id: nil)).not_to be_valid
    expect(make_alert(severity: nil)).not_to be_valid
    expect(make_alert(severity: -2)).not_to be_valid
    expect(make_alert(title: nil)).not_to be_valid
    expect(make_alert(created_at: nil)).not_to be_valid
    expect(make_alert(created_at: 'foobar')).not_to be_valid

    test_alert = make_alert(id: nil, severity: -3, created_at: 'foobar')
    test_alert.validate
    expect(test_alert.error_message)
      .to eq('id is missing, severity is invalid (non-negative integer expected), created_at is invalid UNIX timestamp')
  end

  it 'has short description' do
    expect(make_alert.short_description).to eq('Severity 2: mysql_node/instance_id_abc Test Alert')
  end

  it 'has hash representation' do
    ts = Time.now
    expect(make_alert(created_at: ts.to_i).to_hash).to eq(
      kind: 'alert',
      id: 1,
      severity: 2,
      category: nil,
      title: 'Test Alert',
      summary: 'Everything is down',
      source: 'mysql_node/instance_id_abc',
      deployment: 'deployment',
      created_at: ts.to_i,
    )
  end

  it 'has plain text representation' do
    ts = Time.now
    expect(make_alert(created_at: ts.to_i).to_plain_text).to eq <<-ALERT.gsub(/^\s*/, '')
      mysql_node/instance_id_abc
      Test Alert
      Severity: 2
      Summary: Everything is down
      Time: #{ts.utc}
    ALERT
  end

  it 'has json representation' do
    alert = make_alert
    expect(alert.to_json).to eq(JSON.dump(alert.to_hash))
  end

  it 'has string representation' do
    ts = 1320196099
    alert = make_alert(created_at: ts)
    expect(alert.to_s).to eq('Alert @ 2011-11-02 01:08:19 UTC, severity 2: Everything is down')
  end

  it 'has metrics' do
    expect(make_alert.metrics).to eq([])
  end
end
