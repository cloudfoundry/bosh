require 'spec_helper'
require 'bosh/dev/data_dog_formatter'

module Bosh::Dev
  describe DataDogFormatter do
    subject(:formatter) { DataDogFormatter.new(StringIO.new, sender) }
    let(:sender) { double(DataDogReporter) }
    let(:example) do
      double(RSpec::Core::Example, metadata:
        {
          description: 'sender',
          execution_result: { run_time: 3.14 }
        })
    end

    it { expect(DataDogFormatter).to be < RSpec::Core::Formatters::BaseFormatter }

    it 'should reported to DataDog when an example passes' do
      expect(sender).to receive(:report_on).with(example)
      formatter.example_passed(example)
    end
  end
end
