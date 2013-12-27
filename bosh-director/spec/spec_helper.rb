$: << File.expand_path('..', __FILE__)

require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'digest/sha1'
require 'fileutils'
require 'logger'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'zlib'

require 'archive/tar/minitar'
require 'rspec'
require 'rspec/its'
require 'machinist/sequel'
require 'sham'
require 'support/job_example_group'
require 'support/task_helpers'

RSpec.configure do |config|
  config.include Bosh::Director::Test::TaskHelpers
end

module SpecHelper
  class << self
    attr_accessor :logger
    attr_accessor :temp_dir

    def init
      ENV["RACK_ENV"] = "test"
      configure_logging
      configure_temp_dir

      require "bosh/director"
      @logger.formatter = ThreadFormatter.new

      init_database

      require "blueprints"
    end

    def configure_logging
      if ENV["DEBUG"]
        @logger = Logger.new(STDOUT)
      else
        path = File.expand_path("/tmp/spec.log", __FILE__)
        log_file = File.open(path, "w")
        log_file.sync = true
        @logger = Logger.new(log_file)
      end
    end

    def configure_temp_dir
      @temp_dir = Dir.mktmpdir
      ENV["TMPDIR"] = @temp_dir
      FileUtils.mkdir_p(@temp_dir)
      at_exit do
        begin
          if $!
            status = $!.is_a?(::SystemExit) ? $!.status : 1
          else
            status = 0
          end
          FileUtils.rm_rf(@temp_dir)
        ensure
          exit status
        end
      end
    end

    def init_database
      Bosh::Director::Config.patch_sqlite

      @dns_migrations = File.expand_path("../../db/migrations/dns", __FILE__)
      @director_migrations = File.expand_path("../../db/migrations/director", __FILE__)
      vsphere_cpi_path = $LOAD_PATH.find { |p| File.exist?(File.join(p, File.join("cloud", "vsphere"))) }
      @vsphere_cpi_migrations = File.expand_path("../db/migrations", vsphere_cpi_path)

      Sequel.extension :migration

      connect_database(@temp_dir)

      run_migrations
    end

    def connect_database(path)
      # Sequel with in-memory sqlite database is not thread-safe, using file seems to fix that
      db = "sqlite://#{File.join(path, "director.db")}"
      dns_db = "sqlite://#{File.join(path, "dns.db")}"
      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(db, db_opts)
      @db.loggers << @logger
      Bosh::Director::Config.db = @db

      @dns_db = Sequel.connect(dns_db, db_opts)
      @dns_db.loggers << @logger
      Bosh::Director::Config.dns_db = @dns_db
    end

    def disconnect_database
      if @db
        @db.disconnect
        @db = nil
      end

      if @dns_db
        @dns_db.disconnect
        @dns_db = nil
      end
    end

    def run_migrations
      Sequel::Migrator.apply(@dns_db, @dns_migrations, nil)
      Sequel::Migrator.apply(@db, @director_migrations, nil)
      Sequel::TimestampMigrator.new(@db, @vsphere_cpi_migrations, :table => "vsphere_cpi_schema").run
    end

    def reset_database
      disconnect_database

      if @db_dir && File.directory?(@db_dir)
        FileUtils.rm_rf(@db_dir)
      end

      @db_dir = Dir.mktmpdir(nil, @temp_dir)
      FileUtils.cp(Dir.glob(File.join(@temp_dir, "*.db")), @db_dir)

      connect_database(@db_dir)

      Bosh::Director::Models.constants.each do |e|
        c = Bosh::Director::Models.const_get(e)
        c.db = @db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Bosh::Director::Models::Dns.constants.each do |e|
        c = Bosh::Director::Models::Dns.const_get(e)
        c.db = @dns_db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end
    end

    def reset
      reset_database

      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.dns_db = @dns_db
      Bosh::Director::Config.logger = @logger
    end
  end

  RSpec::Matchers.define :json_match do |matcher|
    match do |actual|
      matcher.matches? JSON.parse(actual)
    end
  end
end

SpecHelper.init

BD = Bosh::Director

RSpec.configure do |rspec|
  rspec.before(:each) do
    unless $redis_63790_started
      redis_config = Tempfile.new('redis_config')
      File.write(redis_config.path, 'port 63790')
      redis_pid = Process.spawn('redis-server', redis_config.path, out: '/dev/null')
      $redis_63790_started = true

      at_exit do
        begin
          if $!
            status = $!.is_a?(::SystemExit) ? $!.status : 1
          else
            status = 0
          end
          redis_config.delete
          Process.kill("KILL", redis_pid)
        ensure
          exit status
        end
      end
    end

    SpecHelper.reset
    @event_buffer = StringIO.new
    @event_log = Bosh::Director::EventLog::Log.new(@event_buffer)
    Bosh::Director::Config.event_log = @event_log
  end
end

RSpec::Matchers.define :have_a_path_of do |expected|
  match do |actual|
    actual.path == expected
  end
end

RSpec::Matchers.define :have_flag_set do |method_name|
  match do |actual|
    actual.send(method_name).should be(true)
  end

  failure_message_for_should do |_|
    "expected '#{method_name}' to be set"
  end

  failure_message_for_should_not do |_|
    "expected '#{method_name}' to be cleared"
  end

  description do
    "have '#{method_name}' flag set"
  end
end

def asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

def spec_asset(filename)
  File.read(asset(filename))
end

def gzip(string)
  result = StringIO.new
  zio = Zlib::GzipWriter.new(result, nil, nil)
  zio.mtime = 1
  zio.write(string)
  zio.close
  result.string
end

def create_stemcell(name, version, cloud_properties, image, sha1)
  io = StringIO.new

  manifest = {
    "name" => name,
    "version" => version,
    "cloud_properties" => cloud_properties,
    "sha1" => sha1
  }

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    tar.add_file("stemcell.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
    tar.add_file("image", {:mode => "0644", :mtime => 0}) { |os, _| os.write(image) }
  end

  io.close
  gzip(io.string)
end

def create_job(name, monit, configuration_files, options = { })
  io = StringIO.new

  manifest = {
    "name" => name,
    "templates" => {},
    "packages" => []
  }

  configuration_files.each do |path, configuration_file|
    manifest["templates"][path] = configuration_file["destination"]
  end

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    unless options[:skip_manifest]
      tar.add_file("job.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
    end
    unless options[:skip_monit]
      monit_file = options[:monit_file] ? options[:monit_file] : "monit"
      tar.add_file(monit_file, {:mode => "0644", :mtime => 0}) { |os, _| os.write(monit) }
    end

    tar.mkdir("templates", {:mode => "0755", :mtime => 0})
    configuration_files.each do |path, configuration_file|
      unless options[:skip_templates] && options[:skip_templates].include?(path)
        tar.add_file("templates/#{path}", {:mode => "0644", :mtime => 0}) do |os, _|
          os.write(configuration_file["contents"])
        end
      end
    end
  end

  io.close

  gzip(io.string)
end

def create_release(name, version, jobs, packages)
  io = StringIO.new

  manifest = {
    "name" => name,
    "version" => version
  }

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    tar.add_file("release.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
    tar.mkdir("packages", {:mode => "0755"})
    packages.each do |package|
      tar.add_file("packages/#{package[:name]}.tgz", {:mode => "0644", :mtime => 0}) { |os, _| os.write("package") }
    end
    tar.mkdir("jobs", {:mode => "0755"})
    jobs.each do |job|
      tar.add_file("jobs/#{job[:name]}.tgz", {:mode => "0644", :mtime => 0}) { |os, _| os.write("job") }
    end
  end

  io.close
  gzip(io.string)
end

def create_package(files)
  io = StringIO.new

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    files.each do |key, value|
      tar.add_file(key, {:mode => "0644", :mtime => 0}) { |os, _| os.write(value) }
    end
  end

  io.close
  gzip(io.string)
end

def check_event_log
  pos = @event_buffer.tell
  @event_buffer.rewind

  events = @event_buffer.read.split("\n").map do |line|
    JSON.parse(line)
  end

  yield events
ensure
  @event_buffer.seek(pos)
end


module ReleaseHelper
  # Creates release tarball using provided manifest.
  # Actual bits are dummy but all specs are meant to satisfy the release.
  # Checksums are filled in automatically to satisfy integrity checks.
  # upload job.
  # @param [Hash] manifest Release manifest
  # @return [String] Directory containing release.tgz
  def create_release_tarball(manifest)
    tmp_dir = Dir.mktmpdir
    release_dir = Dir.mktmpdir

    jobs_dir = File.join(tmp_dir, "jobs")
    packages_dir = File.join(tmp_dir, "packages")

    FileUtils.mkdir(jobs_dir)
    FileUtils.mkdir(packages_dir)

    manifest["jobs"].each do |job|
      job_dir = File.join(jobs_dir, job["name"])
      FileUtils.mkdir(job_dir)
      spec = {
        "name" => job["name"],
        "templates" => job["templates"],
        "packages" => job["packages"]
      }
      File.open(File.join(job_dir, "job.MF"), "w") do |f|
        Psych.dump(spec, f)
      end

      templates_dir = File.join(job_dir, "templates")
      FileUtils.mkdir(templates_dir)

      Dir.chdir(templates_dir) do
        spec["templates"].each_key do |template_path|
          FileUtils.mkdir_p(File.dirname(template_path))
          File.open(template_path, "w") do |f|
            f.write("dummy template")
          end
        end
      end

      File.open(File.join(job_dir, "monit"), "w") do |f|
        f.write("dummy monit file")
      end

      Dir.chdir(jobs_dir) do
        tar_out = `tar -C #{job_dir} -czf #{job["name"]}.tgz . 2>&1`
        if $?.exitstatus != 0
          raise "Cannot create job: #{tar_out}"
        end

        job["sha1"] = Digest::SHA1.file("#{job["name"]}.tgz").hexdigest
      end
      FileUtils.rm_rf(job_dir)
    end

    manifest["packages"].each do |package|
      package_dir = File.join(packages_dir, package["name"])
      FileUtils.mkdir(package_dir)
      File.open(File.join(package_dir, "packaging"), "w") do |f|
        f.write("dummy packaging")
      end

      Dir.chdir(packages_dir) do
        tar_out = `tar -C #{package_dir} -czf #{package["name"]}.tgz . 2>&1`
        if $?.exitstatus != 0
          raise "Cannot create package: #{tar_out}"
        end

        package["sha1"] = Digest::SHA1.file("#{package["name"]}.tgz").hexdigest
      end
      FileUtils.rm_rf(package_dir)
    end

    File.open(File.join(tmp_dir, "release.MF"), "w") do |f|
      Psych.dump(manifest, f)
    end

    Dir.chdir(release_dir) do
      tar_out = `tar -C #{tmp_dir} -czf release.tgz . 2>&1`
      if $?.exitstatus != 0
        raise "Cannot create release: #{tar_out}"
      end
    end

    FileUtils.cp_r(release_dir, "/tmp/foobar")

    release_dir
  end

  module_function :create_release_tarball
end
