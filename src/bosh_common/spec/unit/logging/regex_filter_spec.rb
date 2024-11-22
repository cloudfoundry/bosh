require 'spec_helper'

describe Bosh::Common::Logging::RegexFilter do
  subject { described_class.new(filter) }

  let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }
  let(:event_data) { 'string containing debug-test somewhere' }

  describe '#allow' do
    context 'there is no replacement' do
      let(:filter) { [{ /debug-test/ => nil }] }

      it 'drops messages' do
        expect(subject.allow(event)).to eq(nil)
      end
    end

    context 'there is a replacement' do
      context 'subpatterns' do
        let(:filter) { [{ /debug-test (somewhere)/ => 'REDACTED \1' }] }

        it 'replaces data with subpattern' do
          expect(subject.allow(event).data).to eq('string containing REDACTED somewhere')
        end

        it 'does not change original event_data object' do
          subject.allow(event)

          expect(event_data).to eq('string containing debug-test somewhere')
        end
      end

      context 'plain string replacements' do
        let(:filter) { [{ /debug-test/ => 'REDACTED' }] }

        it 'replaces without subpatterns' do
          expect(subject.allow(event).data).to eq('string containing REDACTED somewhere')
        end
      end

      context 'when string matches multiple filters' do
        let(:filter) { [{ /debug-test/ => 'REDACTED' }, { /REDACTED/ => nil }] }

        it 'chains filters' do
          expect(subject.allow(event)).to eq(nil)
        end
      end

      context 'when string matches multiple filters in a different order' do
        let(:filter) { [{ /REDACTED/ => nil }, { /debug-test/ => 'REDACTED' }] }

        it 'chains filters' do
          expect(subject.allow(event).data).to eq('string containing REDACTED somewhere')
        end
      end
    end

    context 'it does not match' do
      let(:filter) { [{ /no match here/ => nil }] }

      it 'does not touch event' do
        expect(subject.allow(event).data).to eq(event_data)
      end
    end
  end
end
