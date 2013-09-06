require 'spec_helper'

describe Bosh::Agent::Platform do
  describe '#platform' do
    let(:fake_ubuntu) { double('fake ubuntuy') }
    before { Bosh::Agent::Platform::Ubuntu.stub(new: fake_ubuntu) }
    it 'returns an Ubuntu when platform_name is ubuntu' do
      platform = described_class.new('ubuntu')
      expect(platform.platform).to eq(fake_ubuntu)
    end
  end
end
