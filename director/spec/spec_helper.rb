$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)
require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"

ENV["RACK_ENV"] = "test"

require "logger"
if ENV['DEBUG']
  logger = Logger.new(STDOUT)
else
  path = File.expand_path("../spec.log", __FILE__)
  log_file = File.open(path, "w")
  log_file.sync = true
  logger = Logger.new(log_file)
end

require "tmpdir"
tmpdir = Dir.mktmpdir
ENV["TMPDIR"] = tmpdir
FileUtils.mkdir_p(tmpdir)
at_exit { FileUtils.rm_rf(tmpdir) }

require "director"

Bosh::Director::Config.patch_sqlite

# TODO: CLEANUP, duplication between here and below in the reset
director_migrations = File.expand_path("../../db/migrations/director", __FILE__)
vsphere_cpi_migrations = File.expand_path("../../db/migrations/vsphere_cpi", __FILE__)
dns_migrations = File.expand_path("../../db/migrations/dns", __FILE__)

Sequel.extension :migration
db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
db.loggers << logger
Bosh::Director::Config.db = db
Sequel::Migrator.apply(db, director_migrations, nil)
Sequel::TimestampMigrator.new(db, vsphere_cpi_migrations, :table => "vsphere_cpi_schema").run

dns_db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
dns_db.loggers << logger
Bosh::Director::Config.dns_db = dns_db
Sequel::Migrator.apply(dns_db, dns_migrations, nil)

require "archive/tar/minitar"
require "digest/sha1"
require "fileutils"
require "zlib"

require "machinist/sequel"
require "sham"
require "blueprints"

logger.formatter = ThreadFormatter.new

class Object
  include Bosh::Director::DeepCopy
end

def spec_asset(filename)
  File.read(File.expand_path("../assets/#{filename}", __FILE__))
end

def gzip(string)
  result = StringIO.new
  zio = Zlib::GzipWriter.new(result, nil, nil)
  zio.mtime = 1
  zio.write(string)
  zio.close
  result.string
end

def create_stemcell(name, version, cloud_properties, image)
  io = StringIO.new

  manifest = {
    "name" => name,
    "version" => version,
    "cloud_properties" => cloud_properties
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

def reset_db(db)
  db.execute("PRAGMA foreign_keys = OFF")
  db.tables.each do |table|
    db.drop_table(table)
  end
  db.execute("PRAGMA foreign_keys = ON")
end

Rspec.configure do |rspec|
  rspec.before(:each) do |example|
    Bosh::Director::Config.clear
    Bosh::Director::Config.db = db
    Bosh::Director::Config.dns_db = dns_db
    Bosh::Director::Config.logger = logger
    Bosh::Clouds::Config.db = db

    reset_db(db)
    reset_db(dns_db)

    Sequel::Migrator.apply(db, director_migrations, nil)
    Sequel::TimestampMigrator.new(db, vsphere_cpi_migrations, :table => "vsphere_cpi_schema").run
    Sequel::Migrator.apply(dns_db, dns_migrations, nil)

    @event_buffer = StringIO.new
    @event_log = Bosh::Director::EventLog.new(@event_buffer)
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
    actual.send(method_name).should be_true
  end

  failure_message_for_should do |actual|
    "expected `#{method_name}' to be set"
  end

  failure_message_for_should_not do |actual|
    "expected `#{method_name}' to be cleared"
  end

  description do
    "have `#{method_name}' flag set"
  end
end




