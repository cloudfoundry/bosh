require 'spec_helper'

describe Bhm::Metric do

  it "has name, value, timestamp and tags" do
    ts = Time.now
    metric = Bhm::Metric.new("foo", "bar", ts, ["bar", "baz"])
    expect(metric.name).to eq("foo")
    expect(metric.value).to eq("bar")
    expect(metric.timestamp).to eq(ts)
    expect(metric.tags).to eq(["bar", "baz"])
  end

  it "returns a hash representation" do
    ts = Time.now
    metric = Bhm::Metric.new("foo", "bar", ts, ["bar", "baz"])

    expect(metric.to_hash).to eq({
     :name => 'foo',
     :value => 'bar',
     :timestamp => ts.to_i,
     :tags => ['bar', 'baz']
                                 })
  end
end
