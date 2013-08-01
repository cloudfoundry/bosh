require 'spec_helper'
require 'bosh/dev/data_dog_reporter'

module Bosh::Dev
  describe DataDogReporter do
    subject(:sender) { described_class.new(data_dog_client) }
    let(:data_dog_client) { double(Dogapi::Client) }
    let(:example) do
      double(RSpec::Core::Example, metadata:
        {
          full_description: 'foo bar baz',
          execution_result: { run_time: 3.14 }
        })
    end

    before do
      ENV.stub(:fetch).with('BAT_INFRASTRUCTURE').and_return('vsphere')
      subject.stub(:puts)
    end

    it 'should send a message to DataDog when an example passes' do
      data_dog_client.should_receive(:emit_point).with('ci.bosh.bat.duration', 3.14, tags: %w[infrastructure:vsphere example:foo-bar-baz])
      sender.report_on(example)
    end
  end
end
