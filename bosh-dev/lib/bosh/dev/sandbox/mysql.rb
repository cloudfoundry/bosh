require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Mysql
    attr_reader :db_name, :username, :password, :adapter, :port

    # rubocop:disable ParameterLists
    def initialize(db_name, logger, runner = Bosh::Core::Shell.new, username, password)
    # rubocop:enable ParameterLists
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = username
      @password = password
      @adapter = 'mysql2'
      @port = 3306
    end

    def create_db
      @logger.info("Creating mysql database #{db_name}")
      @runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'create database `#{db_name}`;' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      @runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'drop database `#{db_name}`;' > /dev/null 2>&1})
    end

    def current_tasks
      tasks_list_cmd = %Q{mysql --user=#{@username} --password=#{@password} -e "select description, output from tasks where state='processing';" #{db_name}}
      task_lines = `#{tasks_list_cmd}`.lines.to_a[1..-1] || []

      result = []
      task_lines.each do |task_line|
        items = task_line.split("\t").map(&:strip)
        result << {description: items[0], output: items[1] }
      end

      result
    end

    def truncate_db
      @logger.info("Truncating mysql database #{db_name}")
      table_name_cmd = %Q{mysql --user=#{@username} --password=#{@password} -e "show tables;" #{db_name}}
      table_names = `#{table_name_cmd}`.lines.to_a[1..-1].map(&:strip)
      table_names.reject!{|name| name == "schema_migrations" }
      table_names.each do |table_name|
        @runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'SET FOREIGN_KEY_CHECKS=0; truncate table `#{table_name}`; SET FOREIGN_KEY_CHECKS=1;' #{db_name} > /dev/null 2>&1})
      end
    end
  end
end
