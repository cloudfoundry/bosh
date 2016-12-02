require 'spec_helper'

describe Bosh::Cli::TaskTracking::TaskLogRenderer do
  describe '.create_for_log_type' do
    context "when log type is 'event'" do
      it 'returns EventLogRenderer' do
        expect(Bosh::Cli::TaskTracking::EventLogRenderer).to receive(:new)
          .with(no_args)
          .and_return(renderer = double)

        expect(described_class.create_for_log_type('event')).to eq(renderer)
      end
    end

    context "when log type is 'result'" do
      it 'returns NullTaskLogRenderer' do
        expect(described_class.create_for_log_type('result'))
          .to be_an_instance_of(Bosh::Cli::TaskTracking::NullTaskLogRenderer)
      end
    end

    context "when log type is 'none'" do
      it 'returns NullTaskLogRenderer' do
        expect(described_class.create_for_log_type('none'))
          .to be_an_instance_of(Bosh::Cli::TaskTracking::NullTaskLogRenderer)
      end
    end

    context 'when log type is not known' do
      it 'returns TaskLogRenderer' do
        expect(described_class.create_for_log_type('unknown'))
          .to be_an_instance_of(Bosh::Cli::TaskTracking::TaskLogRenderer)
      end
    end
  end
end
