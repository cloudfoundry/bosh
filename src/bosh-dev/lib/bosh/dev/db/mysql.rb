require 'bosh/dev'

module Bosh::Dev::DB
  class Mysql
    DEFAULT_PASSWORD = ( /darwin/ =~ RUBY_PLATFORM) ? '' : 'password'
    attr_reader :db_name, :username, :password, :adapter, :port, :host

    def initialize(db_options:, logger:)
      @adapter = 'mysql2'
      @db_name = db_options[:name]
      @logger = logger

      @username = db_options.fetch(:username, 'root')
      @password = db_options.fetch(:password, DEFAULT_PASSWORD)
      @host = db_options.fetch(:host, '127.0.0.1')
      @port = db_options.fetch(:port, 3306)
    end

    def connection_string(this_db_name = @db_name)
      "mysql2://#{@username}:#{@password}@#{@host}:#{@port}/#{this_db_name}"
    end

    def create_db
      @logger.info("Creating mysql database #{db_name}")
      execute_sql(%Q(CREATE DATABASE `#{db_name}`;), nil)
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      execute_sql(%Q(DROP DATABASE `#{db_name}`;), nil)
    end

    def current_tasks
      task_lines = sql_results_for(%Q(SELECT description, output FROM TASKS WHERE state='processing';))

      result = []
      task_lines.each do |task_line|
        items = task_line.split("\t").map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      sql_results_for(%Q(SELECT * FROM delayed_jobs WHERE locked_by IS NOT NULL;))
    end

    def truncate_db
      @logger.info("Truncating mysql database #{db_name}")
      table_names = sql_results_for(%Q(SHOW TABLES))
      table_names.reject! { |name| name =~ /schema_migrations/ }
      truncate_cmds = table_names.map { |name| %Q(TRUNCATE TABLE `#{name.strip}`;) }

      execute_sql(%Q(SET FOREIGN_KEY_CHECKS=0; #{truncate_cmds.join(' ')}; SET FOREIGN_KEY_CHECKS=1;))
    end

    private

    def run_quietly_redacted(cmd)
      DBHelper.run_command(%Q(#{cmd} > /dev/null 2>&1))
    end

    def execute_sql(sql, this_db_name = db_name)
      run_quietly_redacted(%Q(#{sql_cmd(sql, this_db_name)}))
    end

    def sql_results_for(sql, this_db_name = db_name)
      %x{#{sql_cmd(sql, this_db_name)} 2> /dev/null}.lines.to_a[1..-1] || []
    end

    def sql_cmd(sql, this_db_name)
      %Q(#{mysql_cmd} -e '#{sql.strip}' #{this_db_name})
    end

    def mysql_cmd
      %Q(mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password})
    end
  end
end
