require 'spec_helper'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  describe Agent do
    describe '.for' do
      it 'returns the correct agent' do
        expect(Agent.for('go')).to be_an(Agent::Go)
        expect(Agent.for('ruby')).to be_an(Agent::Ruby)
      end

      it 'raises for unknown instructures' do
        expect {
          Agent.for('BAD_AGENT')
        }.to raise_error(ArgumentError, /invalid agent: BAD_AGENT/)
      end
    end
  end

  describe Agent::Go do
    its(:name) { should eq('go') }
    it { should eq Agent::Go.new }
    it { should_not eq Agent::Ruby.new }
  end

  describe Agent::Ruby do
    its(:name) { should eq('ruby') }
    it { should eq Agent::Ruby.new }
    it { should_not eq Agent::Go.new }
  end
end
