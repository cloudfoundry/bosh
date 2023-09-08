require 'spec_helper'

module Bosh::Director
  describe Timeout do
    describe '#timed_out?' do
      let(:seconds_till_timed_out) { 0.3 }

      before do
        Timecop.freeze(Time.local(1990))
      end

      after do
        Timecop.return
      end

      it 'returns false if it has not timed out' do
        timeout = Timeout.new(seconds_till_timed_out)
        expect(timeout.timed_out?).to eq(false)
      end

      it 'returns true if it has timed out' do
        timeout = Timeout.new(seconds_till_timed_out)
        Timecop.freeze(Date.today + 1) do
          expect(timeout.timed_out?).to eq(true)
        end
      end
    end
  end
end
