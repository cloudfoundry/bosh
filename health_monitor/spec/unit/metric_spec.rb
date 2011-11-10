require 'spec_helper'

describe Bhm::Metric do

  it "has name, value, timestamp and tags" do
    ts = Time.now
    metric = Bhm::Metric.new("foo", "bar", ts, ["bar", "baz"])
    metric.name.should == "foo"
    metric.value.should == "bar"
    metric.timestamp.should == ts
    metric.tags.should == ["bar", "baz"]
  end

  it "validates its attributes" do
    pending
  end

end
