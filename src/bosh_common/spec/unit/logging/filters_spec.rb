require 'spec_helper'
require 'common/logging/regex_filter'
require 'common/logging/filters'
require 'logging/log_event'

describe Bosh::Common::Logging do
  subject { described_class.default_filters[0] }

  let(:event) { Logging::LogEvent.new(nil, 100, event_data, false) }

  describe 'select null' do
    let(:event_data) { '(1.0001s) (conn: 123123123) SELECT NULL' }

    it 'drops them' do
      expect(subject.allow(event)).to eq(nil)
    end
  end

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

  describe 'update statements' do
    let(:event_data) { '(1.001s) (conn: 123123) UPDATE "tablefoo" SET secret = "sensitive" WHERE secret = "c1oudc0w"' }

    it 'redacts them' do
      expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) UPDATE "tablefoo" <redacted>')
    end
  end

  describe 'delete statements' do
    let(:event_data) { '(1.001s) (conn: 123123) DELETE FROM "tablefoo" WHERE secret = "sensitive"' }

    it 'redacts them' do
      expect(subject.allow(event).data).to eq('(1.001s) (conn: 123123) DELETE FROM "tablefoo" <redacted>')
    end
  end
end
