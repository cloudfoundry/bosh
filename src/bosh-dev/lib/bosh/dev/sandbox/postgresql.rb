require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :db_name, :username, :password, :adapter, :port, :host

    def initialize(db_name, logger, port, runner = Bosh::Core::Shell.new, username = 'postgres', password = '', host = 'localhost')
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = username
      @password = password
      @adapter = 'postgres'
      @host = host
      @port = port
    end

    def connection_string
      "postgres://#{@username}:#{@password}@#{@host}:#{@port}/#{@db_name}"
    end

    # Assumption is that user running tests can
    # login via psql without entering password.
    def create_db
      @logger.info("Creating postgres database #{db_name}")
      @runner.run(%Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} -c 'create database "#{db_name}";' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping postgres database #{db_name}")
      @runner.run(%Q{echo 'revoke connect on database "#{db_name}" from public; drop database "#{db_name}";' | PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} > /dev/null 2>&1})
    end

    def dump_db
      @logger.info("Dumping postgres database schema for #{db_name}")
      @runner.run(%Q{PGPASSWORD=#{@password} pg_dump -h #{@host} -p #{@port} -U #{@username} -s "#{db_name}"})
    end

    def describe_db
      @logger.info("Describing postgres database tables for #{db_name}")
      @runner.run(%Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} -d "#{db_name}" -c '\\d+ public.*'})
    end

    def load_db_initial_state(initial_state_assets_dir)
      sql_dump_path = File.join(initial_state_assets_dir, 'postgres_db_snapshot.sql')
      load_db(sql_dump_path)
    end

    def load_db(dump_file_path)
      @logger.info("Loading dump #{dump_file_path} into postgres database #{db_name}")
      @runner.run(%Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} < #{dump_file_path} > /dev/null 2>&1})
    end

    def current_tasks
      tasks_list_cmd = %Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c "select description, output from tasks where state='processing';"}
      task_lines = `#{tasks_list_cmd}`.lines.to_a[2...-2] || []

      result = []
      task_lines.each do |task_line|
        items = task_line.split('|').map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      jobs_cmd = %Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c "select * from delayed_jobs where locked_by is not null;"}
      `#{jobs_cmd}`.lines.to_a[2...-2] || []
    end

    def truncate_db
      @logger.info("Truncating postgres database #{db_name}")

      drop_constraints_cmds_cmd = %Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c "
        SELECT
          CONCAT('ALTER TABLE ',nspname,'.',relname,' DROP CONSTRAINT ',conname,';')
        FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
        ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END,contype,nspname,relname,conname
      "}

      clear_table_cmds_cmd = %Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c "
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

      add_constraints_cmds_cmd = %Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c "
        SELECT
          'ALTER TABLE '||nspname||'.'||relname||' ADD CONSTRAINT '||conname||' '|| pg_get_constraintdef(pg_constraint.oid)||';'
        FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
        ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END DESC,contype DESC,nspname DESC,relname DESC,conname DESC;
      "}

      drop_constraints_cmds = `#{drop_constraints_cmds_cmd}`.lines.to_a[2...-2] || []
      clear_table_cmds = `#{clear_table_cmds_cmd}`.lines.to_a[2...-2] || []
      add_constraints_cmds = `#{add_constraints_cmds_cmd}`.lines.to_a[2...-2] || []

      cmds = drop_constraints_cmds + clear_table_cmds + add_constraints_cmds

      @runner.run(%Q{PGPASSWORD=#{@password} psql -h #{@host} -p #{@port} -U #{@username} #{db_name} -c '#{cmds.join(';')}' > /dev/null 2>&1})
    end
  end
end
