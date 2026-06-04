require 'spec_helper'

RSpec.describe 'Bosh::Director sequel extensions' do
  # -------------------------------------------------------------------------
  # Upstream Sequel gem behaviour pinning
  #
  # These tests confirm that Sequel still exhibits the cached-shared-string
  # behaviour that makes Config#apply_postgres_thread_safety_patch necessary.
  #
  # If any of these expectations start FAILING after a Sequel gem upgrade it
  # means the upstream library has resolved the issue and the monkey patch
  # can be removed.
  # -------------------------------------------------------------------------
  describe 'Sequel::Dataset#select_sql upstream caching behaviour' do
    let(:db) { Sequel.mock }

    it 'returns the SAME String object on successive calls (shared cache)' do
      dataset = db[:templates]

      sql1 = dataset.select_sql
      sql2 = dataset.select_sql

      expect(sql1).to be(sql2),
        'Sequel::Dataset#select_sql is expected to return the SAME cached String object ' \
        'on every call. If this fails after a Sequel upgrade the upstream caching has ' \
        'changed and Config#apply_postgres_thread_safety_patch may no longer be needed.'
    end

    it 'the cached SQL string is mutable (not frozen)' do
      sql = db[:templates].select_sql

      expect(sql).not_to be_frozen,
        'The cached SQL string is expected to be mutable. If this fails after a Sequel ' \
        'upgrade the upstream gem now protects against in-place mutation and the monkey ' \
        'patch may no longer be needed.'
    end

    it 'concurrent callers receive the same object_id, demonstrating the shared-buffer race' do
      dataset = db[:templates]
      ids = Array.new(4) { dataset.select_sql.object_id }

      expect(ids.uniq.length).to eq(1),
        'All concurrent callers are expected to get the SAME String object (same object_id). ' \
        'If this fails the upstream caching behaviour has changed.'
    end
  end

  describe 'String.new(sql) thread-safety pattern' do
    # Root cause: Dataset#select_sql caches and returns the SAME mutable String object
    # to all concurrent callers. Sequel's log_connection_yield prepends "(conn: NNNNN)"
    # in-place to that shared string, which gets injected into the SQL sent to Postgres:
    #   PG::SyntaxError: ERROR: syntax error at or near "conn"
    #
    # Fix: String.new(sql) performs memcpy, giving each execute_query call its own
    # independent C-level buffer — concurrent PQexec calls cannot interfere.
    #
    # This patch is applied in Config#apply_postgres_thread_safety_patch after
    # Sequel.connect (when Sequel::Postgres::Adapter is first loaded).
    # See config_spec.rb for integration-level coverage.

    it 'ensures each invocation receives a fresh String object, not the shared cache' do
      received_sqls = []
      shared_sql = 'SELECT * FROM templates INNER JOIN release_versions_templates ON id = 1'

      base_capture = Module.new do
        define_method(:execute_query) { |sql, _args| received_sqls << sql }
      end

      string_new_patch = Module.new do
        define_method(:execute_query) { |sql, args| super(String.new(sql).freeze, args) }
      end

      klass = Class.new
      klass.include(base_capture)
      klass.prepend(string_new_patch)
      obj = klass.new

      obj.send(:execute_query, shared_sql, nil)
      obj.send(:execute_query, shared_sql, nil)

      expect(received_sqls.all? { |s| s == shared_sql }).to be(true),
        'SQL content must be preserved across the copy'
      expect(received_sqls.map(&:object_id)).not_to include(shared_sql.object_id),
        'No received string should be the original shared object (would allow cross-thread mutation)'
      expect(received_sqls.map(&:object_id).uniq.length).to eq(2),
        'Each invocation must receive a distinct String object (independent buffer per call)'
      expect(received_sqls).to all(be_frozen),
        'Each copy must be frozen so in-place C-level mutations raise FrozenError ' \
        'rather than silently corrupting concurrent threads'
    end

    it 'passes args through to super unmodified' do
      received_args = :unset

      base_capture = Module.new do
        define_method(:execute_query) { |_sql, args| received_args = args }
      end

      string_new_patch = Module.new do
        define_method(:execute_query) { |sql, args| super(String.new(sql).freeze, args) }
      end

      klass = Class.new
      klass.include(base_capture)
      klass.prepend(string_new_patch)

      query_args = [1, 'foo']
      klass.new.send(:execute_query, 'SELECT 1', query_args)

      expect(received_args).to be(query_args), 'args must be passed through without modification'
    end
  end
end
