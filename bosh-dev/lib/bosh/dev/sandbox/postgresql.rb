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

    # Assumption is that user running tests can
    # login via psql without entering password.
    def create_db
      @logger.info("Creating postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres -c 'create database "#{db_name}";' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres -c 'drop database "#{db_name}";' > /dev/null 2>&1})
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
      table_name_cmd = %Q{psql -U postgres #{db_name} -c "select tablename from pg_tables where schemaname='public';"}
      table_names = `#{table_name_cmd}`.lines.to_a[2...-2] || []
      table_names.map!(&:strip)
      table_names.reject! { |name| name == "schema_migrations" }
      table_names.each do |table_name|
        @runner.run(%Q{psql -U postgres #{db_name} -c 'truncate table "#{table_name}" cascade;' > /dev/null 2>&1})
      end
    end
  end
end
