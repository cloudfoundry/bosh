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
end
