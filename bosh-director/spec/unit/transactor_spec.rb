require 'spec_helper'

module Bosh::Director
  describe Transactor do
    subject(:transactor) { Transactor.new }
    let(:fake_db) { instance_double(Sequel::Database) }

    describe '#retryable_transaction' do
      it 'yields to Sequel' do
        def execute(error_message)
          raise error_message
        end

        expect(fake_db).to receive(:transaction).and_return(true)
        expect { transactor.retryable_transaction(fake_db) { execute('blah') } }.to_not raise_error
      end

      context 'when the block returns nil' do
        it 'does not raise "RetryCountExceeded"' do
          expect(fake_db).to receive(:transaction).and_return(nil)
          expect { transactor.retryable_transaction(fake_db) { nil } }.to_not raise_error
        end
      end

      context 'when the block returns an object' do
        it 'bubbles the object up' do
          expect(fake_db).to receive(:transaction).and_return('template')
          expect(transactor.retryable_transaction(fake_db) {}).to eq('template')
        end
      end

      let(:db) { Bosh::Director::Config.db }

      before do
        @success = false
        @tries = 0

        def execute(error_message)
          @tries += 1
          raise Sequel::DatabaseError, error_message if @tries < 3

          @success = true
        end
      end

      context 'when a deadlock error is raised from MySql' do
        it 'retries the transaction on deadlock' do
          expect { transactor.retryable_transaction(db) { execute('Mysql2::Error: Deadlock found when trying to get lock') } }.to_not raise_error
        end
      end

      context 'when a non deadlock mysql error is raised' do
        it 'retries the transaction on deadlock' do
          expect { transactor.retryable_transaction(db) { execute('fail to insert') } }.to raise_error
        end
      end
    end
  end
end
