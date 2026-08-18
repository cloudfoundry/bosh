require 'spec_helper'

RSpec.describe Bosh::Director::Config, '#apply_postgres_thread_safety_patch' do
  # Reset idempotency guard so tests are independent
  before { described_class.instance_variable_set(:@postgres_thread_safety_patched, nil) }
  after  { described_class.instance_variable_set(:@postgres_thread_safety_patched, nil) }

  let(:fake_adapter) do
    Class.new do
      def execute_query(sql, args)
        [sql, args]
      end
      private :execute_query
    end
  end

  context 'when adapter is postgres and Sequel::Postgres::Adapter is defined' do
    before { stub_const('Sequel::Postgres::Adapter', fake_adapter) }

    it 'prepends a module that passes String.new(sql).freeze to prevent cross-thread SQL corruption' do
      described_class.send(:apply_postgres_thread_safety_patch, 'postgres')

      original_sql = 'SELECT * FROM templates INNER JOIN release_versions_templates ON id = 1'
      result = fake_adapter.new.send(:execute_query, original_sql, nil)

      expect(result[0]).to eq(original_sql), 'SQL content must be preserved'
      expect(result[0].object_id).not_to eq(original_sql.object_id),
        'Expected a fresh String.new copy to isolate thread buffers and prevent ' \
        '(conn: NNNNN) prefix injection into the actual SQL sent to Postgres'
      expect(result[0]).to be_frozen,
        'Expected the SQL copy to be frozen so in-place C-level mutations raise FrozenError ' \
        'rather than silently corrupting concurrent threads'
    end

    it 'passes args through to the underlying execute_query unmodified' do
      described_class.send(:apply_postgres_thread_safety_patch, 'postgres')

      query_args = [42, 'bar']
      result = fake_adapter.new.send(:execute_query, 'SELECT 1', query_args)

      expect(result[1]).to be(query_args), 'args must be passed through without modification'
    end

    it 'is idempotent — applies the patch only once even when called multiple times' do
      2.times { described_class.send(:apply_postgres_thread_safety_patch, 'postgres') }

      patched_count = fake_adapter.ancestors.take_while { |m| m != fake_adapter }
                                  .count { |m| m.private_method_defined?(:execute_query) }

      expect(patched_count).to eq(1),
        'Patch must not be stacked — applied exactly once regardless of call count'
    end
  end

  context 'when adapter is not postgres (e.g. mysql2)' do
    before { stub_const('Sequel::Postgres::Adapter', fake_adapter) }

    ["mysql2", "sqlite", nil].each do |adapter|
      it "does not apply the patch for adapter=#{adapter.inspect}" do
        described_class.send(:apply_postgres_thread_safety_patch, adapter)

        patched_count = fake_adapter.ancestors.take_while { |m| m != fake_adapter }
                                    .count { |m| m.private_method_defined?(:execute_query) }

        expect(patched_count).to eq(0),
          "Patch must not be applied when adapter is #{adapter.inspect}"
        expect(described_class.instance_variable_get(:@postgres_thread_safety_patched)).to be_nil
      end
    end
  end

  context 'when adapter is postgres but Sequel::Postgres::Adapter is not yet defined' do
    before { hide_const('Sequel::Postgres::Adapter') }

    it 'does not raise an error' do
      expect { described_class.send(:apply_postgres_thread_safety_patch, 'postgres') }.not_to raise_error
    end

    it 'does not set the patched flag (safe to call again if adapter loads later)' do
      described_class.send(:apply_postgres_thread_safety_patch, 'postgres')
      expect(described_class.instance_variable_get(:@postgres_thread_safety_patched)).to be_nil
    end
  end

  # Tripwire: fires when the vendored pg gem moves past the last version we
  # reviewed, so someone re-checks whether the upstream fix has landed.
  #
  # This patch mitigates a use-after-free in the pg gem's C extension, NOT a Ruby
  # or Sequel defect: pg hands libpq a raw pointer into a Ruby String and then
  # releases the GVL, so GC can relocate or free those bytes mid-send.
  # See Config#apply_postgres_thread_safety_patch for the full explanation.
  #
  # An earlier version of this spec asserted the bug was gone on Ruby 4.0+. That
  # was wrong — the patch was removed on that basis and the corruption was later
  # reproduced on Ruby 4.0.6 with stock pg 1.6.3. Do NOT key this tripwire on the
  # Ruby version again; the fix has to come from pg.
  LAST_REVIEWED_PG_VERSION = '1.6.3'.freeze

  it "fails when pg is upgraded past #{LAST_REVIEWED_PG_VERSION} so ruby-pg#738 can be re-checked" do
    require 'pg'

    current = Gem.loaded_specs['pg']&.version || Gem::Version.new(PG::VERSION)
    reviewed = Gem::Version.new(LAST_REVIEWED_PG_VERSION)

    expect(current).to be <= reviewed, <<~MSG
      pg has been upgraded to #{current} (last reviewed: #{reviewed}).

      Check whether the fix for https://github.com/ged/ruby-pg/issues/738 is in this
      release. The fix copies the query into a pg-owned buffer before the GVL is
      released, so libpq no longer holds a pointer into relocatable Ruby String memory.
      Look for the memcpy/ALLOC_N guard around gvl_PQsendQuery in pgconn_send_query and
      gvl_PQexec in pgconn_sync_exec, in ext/pg_connection.c.

      If the fix IS included:
        - remove Config#apply_postgres_thread_safety_patch and its call in configure_db
        - delete this spec file and sequel_spec.rb's String.new(sql) coverage

      If the fix is NOT included:
        - bump LAST_REVIEWED_PG_VERSION in this spec to #{current}
        - keep the patch and wait for the next pg release
    MSG
  end
end
