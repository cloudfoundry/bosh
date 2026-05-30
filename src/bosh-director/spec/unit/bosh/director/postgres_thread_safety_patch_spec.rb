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

  it 'is obsolete on Ruby 4.0+ and must be removed' do
    # The shared-string mutation bug does not reproduce on Ruby 4.0+.
    # This test fails intentionally when the runtime is upgraded, prompting removal of:
    #   - Config#apply_postgres_thread_safety_patch
    #   - its call site in Config#configure_db
    expect(Gem::Version.new(RUBY_VERSION)).to be < Gem::Version.new('4.0'),
      "Ruby #{RUBY_VERSION} >= 4.0: the Sequel postgres thread-safety patch in " \
      'Config#apply_postgres_thread_safety_patch is no longer needed. ' \
      'Remove the method and its call in configure_db.'
  end
end
