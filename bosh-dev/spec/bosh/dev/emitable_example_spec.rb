require 'spec_helper'
require 'bosh/dev/emitable_example'

module Bosh
  module Dev
    describe EmitableExample do
      let(:run_time) { 3.14 }
      let(:example) do
        double(RSpec::Core::Example, metadata:
          {
            full_description: 'Some context should, r3sult in:some_behavior.',
            execution_result: { run_time: run_time }
          })
      end

      subject do
        ENV.stub(:fetch).with('BAT_INFRASTRUCTURE').and_return('openstack')
        EmitableExample.new(example)
      end

      its(:metric) { should eq 'ci.bosh.bat.duration' }
      its(:value) { should eq run_time }
      its(:options) { should eq(tags: %w[infrastructure:openstack example:some-context-should-r3sult-in-some-behavior]) }
    end
  end
end
