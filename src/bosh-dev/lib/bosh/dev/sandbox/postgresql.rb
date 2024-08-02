require 'bosh/dev'
require 'bosh/core/shell'
require 'shellwords'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :db_name, :username, :password, :adapter, :port, :host, :ca_path

    def initialize(db_name, runner, logger, options = {})
      @db_name = db_name
      @logger = logger
      @runner = runner
      @adapter = 'postgres'

      @username = options.fetch(:username, 'postgres')
      @password = options.fetch(:password, '')
      @port = options.fetch(:port, 5432)
      @host = options.fetch(:host, '127.0.0.1')
      @ca_path = options.fetch(:ca_path, nil)
    end

    def connection_string
      "postgres://#{@username}:#{@password}@#{@host}:#{@port}/#{@db_name}"
    end

    # Assumption is that user running tests can
    # login via psql without entering password.
    def create_db
      @logger.info("Creating postgres database #{db_name}")
      @runner.run(
        "echo #{Shellwords.escape(%(CREATE DATABASE "#{db_name}";))} | " \
        "psql #{connection_string.gsub(/#{@db_name}$/, 'postgres')} > /dev/null",
      )
    end

    def kill_connections
      @logger.info("Killing connections to #{db_name}")
      execute_sql(
        %(
          SELECT pg_terminate_backend(pg_stat_activity.pid)
          FROM pg_stat_activity
          WHERE pg_stat_activity.datname = '#{db_name}' AND pid <> pg_backend_pid();
        ),
      )
    end

    def drop_db
      kill_connections
      @logger.info("Dropping postgres database #{db_name}")
      sql = %(
        REVOKE CONNECT ON DATABASE "#{db_name}" FROM public;
        DROP DATABASE "#{db_name}";
      )
      @runner.run(
        "echo #{Shellwords.escape(sql)} | " \
        "psql #{connection_string.gsub(@db_name, 'postgres')} > /dev/null",
      )
    end

    def dump_db
      @logger.info("Dumping postgres database schema for #{db_name}")
      @runner.run(%(pg_dump #{connection_string}))
    end

    def describe_db
      @logger.info("Describing postgres database tables for #{db_name}")
      @runner.run(%(psql #{connection_string} -c '\\d+ public.*'))
    end

    def load_db_initial_state(initial_state_assets_dir)
      sql_dump_path = File.join(initial_state_assets_dir, 'postgres_db_snapshot.sql')
      load_db(sql_dump_path)
    end

    def load_db(dump_file_path)
      @logger.info("Loading dump #{dump_file_path} into postgres database #{db_name}")
      @runner.run(%(psql #{connection_string} < #{dump_file_path}))
    end

    def current_tasks
      tasks_list_cmd = %(
      psql #{connection_string} -c "
        SELECT description, output
        FROM tasks
        WHERE state='processing';
      "
      )
      task_lines = `#{tasks_list_cmd}`.lines.to_a[2...-2] || []

      result = []
      task_lines.each do |task_line|
        items = task_line.split('|').map(&:strip)
        result << { description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      jobs_cmd = %(
      psql #{connection_string} -c "
        SELECT *
        FROM delayed_jobs
        WHERE locked_by IS NOT NULL;
      "
      )
      `#{jobs_cmd}`.lines.to_a[2...-2] || []
    end

    def truncate_db
      @logger.info("Truncating postgres database #{db_name}")

      drop_constraints_cmds_cmd = %{psql #{connection_string} -c "
        SELECT
          CONCAT('ALTER TABLE ',nspname,'.',relname,' DROP CONSTRAINT ',conname,';')
        FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
        WHERE nspname != 'pg_catalog'
        ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END,contype,nspname,relname,conname
      "}

      clear_table_cmds_cmd = %{psql #{connection_string} -c "
        SELECT
          CONCAT('DELETE FROM \\"', tablename, '\\"')
        FROM pg_tables
        WHERE
          schemaname = 'public' AND
          tablename <> 'schema_migrations'
        UNION
        SELECT
          CONCAT('alter sequence ', relname, ' restart with 1')
        FROM pg_class
        WHERE
          relkind = 'S'
      "}

      add_constraints_cmds_cmd = %{psql #{connection_string} -c "
        SELECT
          'ALTER TABLE '||nspname||'.'||relname||' ADD CONSTRAINT '||conname||' '|| pg_get_constraintdef(pg_constraint.oid)||';'
        FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
        WHERE nspname != 'pg_catalog'
        ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END DESC,contype DESC,nspname DESC,relname DESC,conname DESC;
      "}

      drop_constraints_cmds = `#{drop_constraints_cmds_cmd}`.lines.to_a[2...-2] || []
      clear_table_cmds = `#{clear_table_cmds_cmd}`.lines.to_a[2...-2] || []
      add_constraints_cmds = `#{add_constraints_cmds_cmd}`.lines.to_a[2...-2] || []

      cmds = drop_constraints_cmds + clear_table_cmds + add_constraints_cmds
      @runner.run(
        "psql #{connection_string} -c '#{cmds.join(';')}' > /dev/null 2>&1",
      )
    end

    private

    def execute_sql(statements)
      @runner.run(
        "echo #{Shellwords.escape(statements)} | " \
        "psql #{connection_string} > /dev/null",
      )
    end
  end
end
