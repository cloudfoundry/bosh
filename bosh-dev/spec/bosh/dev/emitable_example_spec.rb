require 'spec_helper'
require 'bosh/dev/emitable_example'

module Bosh::Dev
  describe EmitableExample do
    subject do
      allow(ENV).to receive(:fetch).with('BAT_INFRASTRUCTURE').and_return('openstack')
      EmitableExample.new(example)
    end

    let(:example) do
      instance_double('RSpec::Core::Example', metadata: {
        full_description: 'Some context should, result in:some_behavior.',
        execution_result: { run_time: 3.14 }
      })
    end

    its(:metric)  { should eq('ci.bosh.bat.duration') }
    its(:value)   { should eq(3.14) }
    its(:options) { should eq(tags: %w[infrastructure:openstack example:some-context-should-result-in-some-behavior]) }
  end
end
