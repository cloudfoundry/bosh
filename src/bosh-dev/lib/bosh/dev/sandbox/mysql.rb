require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Mysql
    attr_reader :db_name, :username, :password, :adapter, :port, :host

    def initialize(db_name, logger, runner = Bosh::Core::Shell.new, username = 'root', password = 'password', host = 'localhost')
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = username
      @password = password
      @adapter = 'mysql2'
      @port = 3306
      @host = host
    end

    def connection_string
      "mysql2://#{username}:#{password}@#{@host}:#{@port}/#{@db_name}"
    end

    def create_db
      @logger.info("Creating mysql database #{db_name}")
      @runner.run(%Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e 'create database `#{db_name}`;' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      @runner.run(%Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e 'drop database `#{db_name}`;' > /dev/null 2>&1})
    end

    def load_db_initial_state(initial_state_assets_dir)
      sql_dump_path = File.join(initial_state_assets_dir, 'mysql_db_snapshot.sql')
      load_db(sql_dump_path)
    end

    def load_db(dump_file_path)
      @logger.info("Loading dump '#{dump_file_path}' into mysql database #{db_name}")
      @runner.run(%Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} #{db_name} < #{dump_file_path} > /dev/null 2>&1})
    end

    def current_tasks
      tasks_list_cmd = %Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e "select description, output from tasks where state='processing';" #{db_name} 2> /dev/null}
      task_lines = `#{tasks_list_cmd}`.lines.to_a[1..-1] || []

      result = []
      task_lines.each do |task_line|
        items = task_line.split("\t").map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def current_locked_jobs
      jobs_cmd = %Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e "select * from delayed_jobs where locked_by is not null;" #{db_name} 2> /dev/null}
      job_lines = `#{jobs_cmd}`.lines.to_a[1..-1] || []

      job_lines
    end

    def truncate_db
      @logger.info("Truncating mysql database #{db_name}")
      table_name_cmd = %Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e "show tables;" #{db_name} 2>/dev/null}
      table_names = `#{table_name_cmd}`.lines.to_a[1..-1].map(&:strip)
      table_names.reject!{|name| name == "schema_migrations" }
      truncates = table_names.map{|name| 'truncate table `' + name + '`' }.join(';')
      @runner.run(%Q{mysql -h #{@host} -P #{@port} --user=#{@username} --password=#{@password} -e 'SET FOREIGN_KEY_CHECKS=0; #{truncates}; SET FOREIGN_KEY_CHECKS=1;' #{db_name} > /dev/null 2>&1})
    end
  end
end
