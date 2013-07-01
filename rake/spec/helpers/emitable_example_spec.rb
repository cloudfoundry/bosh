require 'spec_helper'
require_relative '../../lib/helpers/emitable_example'

module Bosh
  module Helpers
    describe EmitableExample do
      let(:run_time) { 3.14 }
      let(:example) do
        double(RSpec::Core::Example, metadata:
          {
            description: 'foo bar baz',
            execution_result: {run_time: run_time}
          })
      end

      subject do
        EmitableExample.new(example)
      end

      its(:metric) { should eq 'bosh.ci.bat.test_example_duration3' }
      its(:value) { should eq run_time }
      its(:options) { should eq(tags: %w[infrastructure:test example:foo-bar-baz]) }

      pending 'include example group(s) in description'
    end
  end
end
