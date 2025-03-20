require 'spec_helper'

describe Bosh::Director::Duration do
  it 'should calculate basic duration' do
    expect(Bosh::Director::Duration.duration(0)).to eq('0 seconds')
    expect(Bosh::Director::Duration.duration(1)).to eq('1 second')
    expect(Bosh::Director::Duration.duration(1.5)).to eq('1.5 seconds')
    expect(Bosh::Director::Duration.duration(60)).to eq('1 minute')
    expect(Bosh::Director::Duration.duration(61)).to eq('1 minute 1 second')
    expect(Bosh::Director::Duration.duration(2 * 60)).to eq('2 minutes')
    expect(Bosh::Director::Duration.duration(2 * 60 + 1)).to eq('2 minutes 1 second')
    expect(Bosh::Director::Duration.duration(60 * 60)).to eq('1 hour')
    expect(Bosh::Director::Duration.duration(2 * 60 * 60)).to eq('2 hours')
    expect(Bosh::Director::Duration.duration(2 * 60 * 60 + 60 + 1)).to eq('2 hours 1 minute 1 second')
    expect(Bosh::Director::Duration.duration(24 * 60 * 60)).to eq('1 day')
    expect(Bosh::Director::Duration.duration(24 * 60 * 60 + 1)).to eq('1 day 1 second')
    expect(Bosh::Director::Duration.duration(48 * 60 * 60)).to eq('2 days')
  end
end
