$:.unshift(File.expand_path("../../lib", __FILE__))

ENV['RACK_ENV'] = "test"

require "director"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

bosh_dir = Dir.mktmpdir("boshdir")
bosh_tmp_dir = Dir.mktmpdir("bosh_tmpdir")

ENV["TMPDIR"] = bosh_tmp_dir

class Object
  include Bosh::Director::DeepCopy
end

Spec::Runner.configure do |rspec_config|
  rspec_config.before(:each) do
    FileUtils.mkdir_p(bosh_dir)
  end

  rspec_config.after(:each) do
    FileUtils.rm_rf(bosh_dir)
  end

  rspec_config.after(:all) do
    FileUtils.rm_rf(bosh_tmp_dir)
  end
end
