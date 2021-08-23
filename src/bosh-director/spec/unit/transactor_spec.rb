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

      before do
        def execute(error_message)
          success = false
          tries = 0

          allow(fake_db).to receive(:transaction) do
            tries += 1
            raise Sequel::DatabaseError, error_message if tries < 3

            success = true
          end
        end
      end

      it 'passes the retry count and exception' do
        retries = []
        allow(fake_db).to receive(:transaction).and_yield
        expect do
          transactor.retryable_transaction(fake_db) do |retry_count|
            retries.push retry_count
            raise Sequel::DatabaseError, 'Mysql2::Error: Deadlock found when trying to get lock' if retries.length < 3
          end
        end.to_not raise_error

        expect(retries).to eq([1, 2, 3])
      end

      context 'when a deadlock error is raised from MySql' do
        it 'retries the transaction on deadlock' do
          execute('Mysql2::Error: Deadlock found when trying to get lock')
          expect { transactor.retryable_transaction(fake_db) }.to_not raise_error
        end
      end

      context 'when a non deadlock mysql error is raised' do
        it 'retries the transaction on deadlock' do
          execute('fail to insert')
          expect { transactor.retryable_transaction(fake_db) }.to raise_error(/fail to insert/)
        end
      end
    end
  end
end
