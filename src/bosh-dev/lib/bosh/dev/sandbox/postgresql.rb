require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :db_name, :username, :password, :adapter, :port

    def initialize(db_name, logger, port, runner = Bosh::Core::Shell.new)
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = 'postgres'
      @password = ''
      @adapter = 'postgres'
      @port = port
    end

    def connection_string
      "postgres://#{@username}:#{@password}@localhost:#{@port}/#{@db_name}"
    end

    # Assumption is that user running tests can
    # login via psql without entering password.
    def create_db
      @logger.info("Creating postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres -c 'create database "#{db_name}";' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping postgres database #{db_name}")
      @runner.run(%Q{echo 'revoke connect on database "#{db_name}" from public; drop database "#{db_name}";' | psql -U postgres})
    end

    def load_db_initial_state(initial_state_assets_dir)
      sql_dump_path = File.join(initial_state_assets_dir, 'postgres_db_snapshot.sql')
      load_db(sql_dump_path)
    end

    def load_db(dump_file_path)
      @logger.info("Loading dump #{dump_file_path} into postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres #{db_name} < #{dump_file_path} > /dev/null 2>&1})
    end

    def current_tasks
      tasks_list_cmd = %Q{psql -U postgres #{db_name} -c "select description, output from tasks where state='processing';"}
      task_lines = `#{tasks_list_cmd}`.lines.to_a[2...-2] || []

      result = []
      task_lines.each do |task_line|
        items = task_line.split('|').map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      jobs_cmd = %Q{psql -U postgres #{db_name} -c "select * from delayed_jobs where locked_by is not null;"}
      `#{jobs_cmd}`.lines.to_a[2...-2] || []
    end

    def truncate_db
      @logger.info("Truncating postgres database #{db_name}")
      cmds_cmd = %Q{psql -U postgres #{db_name} -c "
        SELECT CONCAT('truncate table \\"', tablename, '\\" cascade')
        FROM pg_tables
        WHERE
          schemaname = 'public' AND
          tablename <> 'schema_migrations'
        UNION
        SELECT CONCAT('alter sequence ', relname, ' restart with 1')
        FROM pg_class
        WHERE relkind = 'S'
       "}
      cmds = `#{cmds_cmd}`.lines.to_a[2...-2] || []
      @runner.run(%Q{psql -U postgres #{db_name} -c '#{cmds.join(';')}' > /dev/null 2>&1})
    end
  end
end
