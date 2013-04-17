require 'spec_helper'

describe Bosh::Clouds::Provider do
  it 'should create a provider instance' do
    provider = Bosh::Clouds::Provider.create('spec', {})
    provider.should be_kind_of(Bosh::Clouds::Spec)
  end

  it 'should fail to create an invalid provider' do
    expect {
      Bosh::Clouds::Provider.create("enoent", {})
    }.to raise_error(Bosh::Clouds::CloudError, /Could not load Cloud Provider Plugin: enoent/)
  end
end
