require 'spec_helper'

describe Bosh::Monitor::Metric do
  it 'has name, value, timestamp and tags' do
    ts = Time.now
    metric = Bosh::Monitor::Metric.new('foo', 'bar', ts, %w[bar baz])
    expect(metric.name).to eq('foo')
    expect(metric.value).to eq('bar')
    expect(metric.timestamp).to eq(ts)
    expect(metric.tags).to eq(%w[bar baz])
  end

  it 'returns a hash representation' do
    ts = Time.now
    metric = Bosh::Monitor::Metric.new('foo', 'bar', ts, %w[bar baz])

    expect(metric.to_hash).to eq(
      name: 'foo',
      value: 'bar',
      timestamp: ts.to_i,
      tags: %w[bar baz],
    )
  end
end
