require 'spec_helper'

module Bosh::Director
  describe RegexLoggingFilter do
    subject { described_class.new(filter) }

    let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }
    let(:event_data) { 'string containing debug-test somewhere' }

    let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }

    describe '.null_query_filter' do
      subject { RegexLoggingFilter.null_query_filter }

      describe 'select null' do
        let(:event_data) { '(1.0001s) (conn: 123123123) SELECT NULL' }

        it 'drops them' do
          expect(subject.allow(event)).to eq(nil)
        end
      end
    end

    describe '.query_redaction_filter' do
      subject { RegexLoggingFilter.query_redaction_filter }

      describe 'postgres' do
        describe 'insert db queries' do
          describe 'insert into statements' do
            let(:event_data) { '(1.001s) (conn: 123123) INSERT INTO "tablefoo" VALUES ("sensitive")' }

            it 'redacts them' do
              expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) INSERT INTO "tablefoo" <redacted>')
            end
          end

          describe 'multiline insert into statements' do
            let(:event_data) { "(1.001s) (conn: 123123) INSERT INTO \"tablefoo\"\nVALUES (\"sensitive\")" }

            it 'redacts them' do
              expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) INSERT INTO "tablefoo" <redacted>')
            end
          end
        end

        describe 'update db queries' do
          let(:event_data) { '(1.001s) (conn: 123123) UPDATE "tablefoo" SET secret = "sensitive" WHERE secret = "c1oudc0w"' }

          it 'redacts them' do
            expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) UPDATE "tablefoo" <redacted>')
          end
        end

        describe 'delete db queries' do
          let(:event_data) { '(1.001s) (conn: 123123) DELETE FROM "tablefoo" WHERE secret = "sensitive"' }

          it 'redacts them' do
            expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) DELETE FROM "tablefoo" <redacted>')
          end
        end
      end

      describe 'mysql' do
        describe 'insert db queries' do
          describe 'insert into statements' do
            let(:event_data) { '(1.001s) (conn: 123123) INSERT INTO `tablefoo` VALUES (`sensitive`)' }

            it 'redacts them' do
              expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) INSERT INTO `tablefoo` <redacted>')
            end
          end

          describe 'multiline insert into statements' do
            let(:event_data) { "(1.001s) (conn: 123123) INSERT INTO `tablefoo`\nVALUES (`sensitive`)" }

            it 'redacts them' do
              expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) INSERT INTO `tablefoo` <redacted>')
            end
          end
        end

        describe 'update db queries' do
          let(:event_data) { '(1.001s) (conn: 123123) UPDATE `tablefoo` SET secret = `sensitive` WHERE secret = `c1oudc0w`' }

          it 'redacts them' do
            expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) UPDATE `tablefoo` <redacted>')
          end
        end

        describe 'delete db queries' do
          let(:event_data) { '(1.001s) (conn: 123123) DELETE FROM `tablefoo` WHERE secret = `sensitive`' }

          it 'redacts them' do
            expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) DELETE FROM `tablefoo` <redacted>')
          end
        end
      end
    end

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
end
