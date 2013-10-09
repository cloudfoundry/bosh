require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :directory

    def initialize(directory, runner = Bosh::Core::Shell.new)
      @directory = directory
      @runner = runner
    end

    def setup
      runner.run("initdb -D #{directory}")
    end

    def run
      runner.run("pg_ctl start -D #{directory} -l #{directory}/pg.log")
    end

    def destroy
      runner.run("pg_ctl stop -m immediate -D #{directory}")
    end

    def dump
      runner.run("pg_dump --host #{directory} --format=custom --file=#{dump_path} postgres")
    end

    def restore
      runner.run("pg_restore --host #{directory} --clean --format=custom --file=#{dump_path}")
    end

    private

    attr_reader :runner

    def dump_path
      "#{directory}/postgresql_backup"
    end

  end
end
