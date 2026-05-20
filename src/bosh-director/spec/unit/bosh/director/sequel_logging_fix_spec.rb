# @AI-Generated
# Modified with AI assistance
# Description:
# 2026-05-19: Spec for Sequel log_connection_yield YJIT race condition fix - Cursor: Claude Sonnet 4.6

require 'spec_helper'

describe Bosh::Director::SequelLoggingFix do
  # TNZ-103317: Sequel's log_connection_yield reassigned its `sql` parameter to
  # prepend "(conn: N)" for logging. Under YJIT, blocks closed over the caller's
  # `sql` variable could capture the modified value, causing the conn prefix to
  # be sent to PostgreSQL as SQL and raising a PG::SyntaxError.

  let(:log_messages) { [] }
  let(:logger) { instance_double(Logger).tap { |l| allow(l).to receive(:debug) { |m| log_messages << m } } }

  let(:db) do
    Sequel.connect('mock://').tap do |d|
      d.loggers = [logger]
      d.log_connection_info = true
    end
  end

  let(:conn) { double('conn', __id__: 12345) }

  it 'is prepended to Sequel::Database' do
    expect(Sequel::Database.ancestors).to include(described_class)
  end

  describe '#log_connection_yield' do
    it 'yields to the block' do
      yielded = false
      db.log_connection_yield('SELECT 1', conn) { yielded = true }
      expect(yielded).to be true
    end

    it 'logs the (conn: N) prefix together with the original SQL' do
      db.log_connection_yield('SELECT 1', conn) { nil }
      expect(log_messages.join(' ')).to match(/\(conn: 12345\).*SELECT 1/)
    end

    it 'does not expose the (conn: N)-prefixed string to the block' do
      # Simulate postgres.rb's pattern: the block captures `sql` from its own
      # closure scope (the caller's local variable), not from inside
      # log_connection_yield. The fix ensures the two cannot be confused.
      sql = 'SELECT 1'
      sql_as_seen_by_block = nil

      db.log_connection_yield(sql, conn) do
        sql_as_seen_by_block = sql
      end

      expect(sql_as_seen_by_block).to eq('SELECT 1')
      expect(sql_as_seen_by_block).not_to start_with('(conn:')
    end

    it 'logs the (conn: N) prefix in exceptions raised inside the block' do
      allow(logger).to receive(:error) { |m| log_messages << m }

      expect do
        db.log_connection_yield('SELECT bad', conn) { raise Sequel::DatabaseError, 'boom' }
      end.to raise_error(Sequel::DatabaseError)

      expect(log_messages.join(' ')).to match(/\(conn: 12345\).*SELECT bad/)
    end

    context 'when log_connection_info is false' do
      before { db.log_connection_info = false }

      it 'does not include (conn: N) in the log message' do
        db.log_connection_yield('SELECT 1', conn) { nil }
        expect(log_messages.join).not_to include('(conn:')
      end
    end

    context 'when no loggers are set' do
      before { db.loggers = [] }

      it 'yields without logging' do
        yielded = false
        db.log_connection_yield('SELECT 1', conn) { yielded = true }
        expect(yielded).to be true
        expect(log_messages).to be_empty
      end
    end
  end
end
