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

require "director"

Bosh::Director::Config.patch_sqlite

migrate_dir = File.expand_path("../../db/migrations", __FILE__)
Sequel.extension :migration
db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
db.loggers << logger
Sequel::Model.db = db
Sequel::Migrator.apply(db, migrate_dir, nil)

require "archive/tar/minitar"
require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

require "machinist/sequel"
require "sham"
require "blueprints"

bosh_dir = Dir.mktmpdir("boshdir")
bosh_tmp_dir = Dir.mktmpdir("bosh_tmpdir")

ENV["TMPDIR"] = bosh_tmp_dir

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

def create_job(name, monit, configuration_files)
  io = StringIO.new

  manifest = {
    "name" => name,
    "templates" => {}
  }

  configuration_files.each do |path, configuration_file|
    manifest["templates"][path] = configuration_file["destination"]
  end

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    tar.add_file("job.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
    tar.add_file("monit", {:mode => "0644", :mtime => 0}) { |os, _| os.write(monit) }

    tar.mkdir("templates", {:mode => "0755", :mtime => 0})
    configuration_files.each do |path, configuration_file|
      tar.add_file("templates/#{path}", {:mode => "0644", :mtime => 0}) do |os, _|
        os.write(configuration_file["contents"])
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

Rspec.configure do |rspec_config|

  rspec_config.before(:each) do |example|
    Bosh::Director::Config.clear

    db.execute("PRAGMA foreign_keys = OFF")
    db.tables.each do |table|
      db.drop_table(table)
    end
    db.execute("PRAGMA foreign_keys = ON")

    Sequel::Migrator.apply(db, migrate_dir, nil)
    FileUtils.mkdir_p(bosh_dir)
    Bosh::Director::Config.logger = logger
  end

  rspec_config.after(:each) do
    FileUtils.rm_rf(bosh_dir)
  end

  rspec_config.after(:all) do
    FileUtils.rm_rf(bosh_tmp_dir)
  end
end

RSpec::Matchers.define :have_a_path_of do |expected|
  match do |actual|
    actual.path == expected
  end
end

