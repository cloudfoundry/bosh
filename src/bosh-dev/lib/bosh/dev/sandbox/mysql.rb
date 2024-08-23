require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Mysql
    attr_reader :db_name, :username, :password, :adapter, :port, :host, :ca_path

    def initialize(db_name, runner, logger, options = {})
      @db_name = db_name
      @logger = logger
      @runner = runner
      @adapter = 'mysql2'

      @username = options.fetch(:username, 'root')
      @password = options.fetch(:password, 'password')
      @port = options.fetch(:port, 3306)
      @host = options.fetch(:host, 'localhost')
      @ca_path = options.fetch(:ca_path, nil)
    end

    def connection_string
      "mysql2://#{username}:#{password}@#{@host}:#{@port}/#{@db_name}"
    end

    def create_db
      @logger.info("Creating mysql database #{db_name}")
      execute_sql(%{CREATE DATABASE `#{db_name}`;}, nil)
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      execute_sql(%{DROP DATABASE `#{db_name}`;}, nil)
    end

    def load_db_initial_state(initial_state_assets_dir)
      sql_dump_path = File.join(initial_state_assets_dir, 'mysql_db_snapshot.sql')
      load_db(sql_dump_path)
    end

    def load_db(dump_file_path)
      @logger.info("Loading dump '#{dump_file_path}' into mysql database #{db_name}")
      run_quietly_redacted(%Q{#{mysql_cmd} #{db_name} < #{dump_file_path} > /dev/null 2>&1})
    end

    def current_tasks
      task_lines = sql_results_for(%{SELECT description, output FROM TASKS WHERE state='processing';})

      result = []
      task_lines.each do |task_line|
        items = task_line.split("\t").map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      sql_results_for(%{SELECT * FROM delayed_jobs WHERE locked_by IS NOT NULL;})
    end

    def truncate_db
      @logger.info("Truncating mysql database #{db_name}")
      table_names = sql_results_for(%{SHOW TABLES})
      table_names.reject! { |name| name == 'schema_migrations' }
      truncate_cmds = table_names.map { |name| %{TRUNCATE TABLE '#{name.strip}'} }

      execute_sql(%{SET FOREIGN_KEY_CHECKS=0; #{truncate_cmds.join(';')}; SET FOREIGN_KEY_CHECKS=1;})
    end

    private

    def run_quietly_redacted(cmd)
      redacted = [@password] unless @password.blank?
      @runner.run(%{#{cmd} > /dev/null 2>&1}, redact: redacted)
    end

    def execute_sql(sql, this_db_name = db_name)
      run_quietly_redacted(%{#{sql_cmd(sql, this_db_name)} > /dev/null 2>&1})
    end

    def sql_results_for(sql, this_db_name = db_name)
      %x{#{sql_cmd(sql, this_db_name)} 2> /dev/null}.lines.to_a[1..-1] || []
    end

    def sql_cmd(sql, this_db_name)
      %{#{mysql_cmd} -e '#{sql.strip}' #{this_db_name}}
    end

    def mysql_cmd
      %{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password}}
    end
  end
end
