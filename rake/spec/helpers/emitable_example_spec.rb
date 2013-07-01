require 'spec_helper'
require_relative '../../lib/helpers/emitable_example'

module Bosh
  module Helpers
    describe EmitableExample do
      let(:run_time) { 3.14 }
      let(:example) do
        double(RSpec::Core::Example, metadata:
          {
            full_description: 'Some context should, r3sult in some_behavior.',
            execution_result: {run_time: run_time}
          })
      end

      subject do
        EmitableExample.new(example)
      end

      its(:metric) { should eq 'bosh.ci.bat.test_example_duration3' }
      its(:value) { should eq run_time }
      its(:options) { should eq(tags: %w[infrastructure:test example:some-context-should-r3sult-in-some-behavior]) }
    end
  end
end
