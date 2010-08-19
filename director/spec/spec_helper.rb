$:.unshift(File.expand_path("../../lib", __FILE__))

ENV['RACK_ENV'] = "test"

require "director"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

Bundler.require(:test)

bosh_dir = Dir.mktmpdir("boshdir")
bosh_tmp_dir = Dir.mktmpdir("bosh_tmpdir")

ENV["TMPDIR"] = bosh_tmp_dir

config = {
  "dir" => bosh_dir,
  "redis" => {
    "host" => "127.0.0.1",
    "port" => 16379,
    "password" => nil },
  "logging" => {
    "level" => "INFO"
  }
}

Bosh::Director::Config.configure(config)

class Object
  def _deep_copy
    Marshal::load(Marshal::dump(self))
  end
end

Spec::Runner.configure do |rspec_config|
  rspec_config.before(:each) do
    Bosh::Director::Config.redis.flushdb
    FileUtils.mkdir_p(bosh_dir)
  end

  rspec_config.after(:each) do
    FileUtils.rm_rf(bosh_dir)
  end

  rspec_config.after(:all) do
    FileUtils.rm_rf(bosh_tmp_dir)
  end
end
