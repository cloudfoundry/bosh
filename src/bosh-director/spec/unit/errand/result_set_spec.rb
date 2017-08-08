require 'spec_helper'

module Bosh::Director
  describe Errand::ResultSet do
    subject(:set) { Errand::ResultSet.new(results) }
    let(:results) do
      [
        successful_result1, successful_result2,
        errored_result1, errored_result2, errored_result3,
        cancelled_result1,
        skipped_result1, skipped_result2, skipped_result3, skipped_result4,
      ]
    end
    let(:successful_result1) { Errand::Result.new(errand_name, 0, '', '', nil) }
    let(:successful_result2) { Errand::Result.new(errand_name, 0, '', '', nil) }
    let(:errored_result1) { Errand::Result.new(errand_name, 1, '', '', nil) }
    let(:errored_result2) { Errand::Result.new(errand_name, 1, '', '', nil) }
    let(:errored_result3) { Errand::Result.new(errand_name, 1, '', '', nil) }
    let(:cancelled_result1) { Errand::Result.new(errand_name, 256, '', '', nil) }
    let(:skipped_result1) { Errand::Result.new(errand_name, -1, '', '', nil) }
    let(:skipped_result2) { Errand::Result.new(errand_name, -1, '', '', nil) }
    let(:skipped_result3) { Errand::Result.new(errand_name, -1, '', '', nil) }
    let(:skipped_result4) { Errand::Result.new(errand_name, -1, '', '', nil) }
    let(:errand_name) { 'test-errand' }

    describe '#summary' do
      it 'returns summary string' do
        expect(set.summary).to eq("2 succeeded, 3 errored, 1 canceled, 4 skipped")
      end
    end
  end
end
