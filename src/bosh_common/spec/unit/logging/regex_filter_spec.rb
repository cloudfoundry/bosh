require 'spec_helper'
require 'common/logging/regex_filter'
require 'logging/log_event'

describe Bosh::Common::Logging::RegexFilter do
  subject { described_class.new(blacklist) }

  let(:blacklist) { [/debug-test/] }
  let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }

  describe '#allow' do
    context 'event data contains blacklist match' do
      let(:event_data) { 'string containing debug-test somewhere' }

      it 'is disallowed' do
        expect(subject.allow(event)).to eq(nil)
      end
    end

    context 'event data does not contain blacklist match' do
      let(:event_data) { 'this message should not be filtered' }

      it 'is allowed' do
        expect(subject.allow(event)).to eq(event)
      end
    end
  end
end
