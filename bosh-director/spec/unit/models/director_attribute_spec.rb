require 'spec_helper'
require 'logger'
require 'bosh/director/models/director_attribute'

module Bosh::Director::Models
  describe DirectorAttribute do
    describe '.find_or_create_uuid' do
      let(:logger) { Logger.new('/dev/null') }

      context 'when uuid is found' do
        it 'returns uuid value' do
          described_class.create(name: 'uuid', value: 'fake-uuid')
          expect(described_class.find_or_create_uuid(logger)).to eq('fake-uuid')
        end
      end

      context 'when uuid cannot be found' do
        before { described_class.delete }

        context 'when creation of uuid fails with database constraint' do
          before { allow(described_class).to receive(:create).and_raise(Sequel::DatabaseError, 'error') }

          it 'fetches uuid value from the database since it was populated since initial check' do
            initial_uuid = nil
            later_uuid = described_class.new(value: 'fake-uuid')
            expect(described_class).to receive(:first)
              .with(name: 'uuid')
              .and_return(initial_uuid, later_uuid)
            expect(described_class.find_or_create_uuid(logger)).to eq('fake-uuid')
          end
        end

        context 'when creation of uuid succeeds' do
          it 'saves and returns newly created uuid' do
            expect(SecureRandom).to receive(:uuid).and_return('fake-uuid')
            expect {
              @uuid = described_class.find_or_create_uuid(logger)
            }.to change { described_class.all.size }.by(1)
            expect(@uuid).to eq('fake-uuid')
          end
        end
      end
    end

    describe '.update_or_create_uuid' do
      let(:logger) { Logger.new('/dev/null') }

      context 'when uuid is found' do
        context 'when old uuid is same as new' do
          before { described_class.create(name: 'uuid', value: 'fake-uuid') }

          it 'keeps uuid value the same' do
            described_class.update_or_create_uuid('fake-uuid', logger)
            expect(described_class.first(name: 'uuid').value).to eq('fake-uuid')
          end

          it 'returns uuid value' do
            described_class.update_or_create_uuid('fake-uuid', logger)
            expect(described_class.first(name: 'uuid').value).to eq('fake-uuid')
          end
        end

        context 'when old uuid is different from old uuid' do
          before { described_class.create(name: 'uuid', value: 'fake-old-uuid') }

          it 'updates uuid value' do
            described_class.update_or_create_uuid('fake-uuid', logger)
            expect(described_class.first(name: 'uuid').value).to eq('fake-uuid')
          end

          it 'returns uuid value' do
            uuid = described_class.update_or_create_uuid('fake-uuid', logger)
            expect(uuid).to eq('fake-uuid')
          end
        end
      end

      context 'when uuid cannot be found' do
        before { described_class.delete }

        it 'creates uuid with given value' do
          described_class.update_or_create_uuid('fake-uuid', logger)
          expect(described_class.first(name: 'uuid').value).to eq('fake-uuid')
        end

        it 'returns uuid value' do
          uuid = described_class.update_or_create_uuid('fake-uuid', logger)
          expect(uuid).to eq('fake-uuid')
        end
      end
    end

    describe 'validations' do
      [nil, ''].each do |invalid_name|
        it "does not allow name with #{invalid_name.inspect}" do
          expect {
            described_class.create(name: invalid_name)
          }.to raise_error(Sequel::ValidationFailed, /name presence/)
        end
      end

      it 'allows attribute with name if one is not already found' do
        expect {
          described_class.create(name: 'fake-name', value: 'fake-uuid')
        }.to change { described_class.all.size }.to(1)
      end

      it 'does not allow attribute with name if one is already found via database ' +
         '(DB uniqueness is important since we rely that only one uuid is used by the director)' do
        described_class.create(name: 'fake-name', value: 'fake-uuid')
        expect {
          described_class.create(name: 'fake-name', value: 'other-fake-uuid')
        }.to raise_error(Sequel::DatabaseError, /column name is not unique/)
      end
    end
  end
end
