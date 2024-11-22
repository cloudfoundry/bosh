require 'spec_helper'

describe Bosh::Common::Logging do
  let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }

  describe '#null_query_filter' do
    let(:subject) { described_class.null_query_filter }

    describe 'select null' do
      let(:event_data) { '(1.0001s) (conn: 123123123) SELECT NULL' }

      it 'drops them' do
        expect(subject.allow(event)).to eq(nil)
      end
    end
  end

  describe '#query_redaction_filter' do
    let(:subject) { described_class.query_redaction_filter }

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
end
