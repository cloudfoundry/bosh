require 'spec_helper'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  describe Agent do
    describe '.for' do
      it 'returns the correct agent' do
        expect(Agent.for('go')).to be_an(Agent::Go)
        expect(Agent.for('null')).to be_an(Agent::NullAgent)
      end

      it 'raises for unknown instructures' do
        expect {
          Agent.for('BAD_AGENT')
        }.to raise_error(ArgumentError, /invalid agent: BAD_AGENT/)
      end
    end
  end

  describe Agent::NullAgent do
    it 'has a name' do
      expect(subject.name).to eq ('null')
    end

    it 'is comparable to other agents' do
      expect(subject).to eq(Agent::NullAgent.new)
      expect(subject).to_not eq(Agent::Go.new)
    end
  end

  describe Agent::Go do
    its(:name) { should eq('go') }
    it { should eq Agent::Go.new }
  end
end
