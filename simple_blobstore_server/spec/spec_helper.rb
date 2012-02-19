ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
Bundler.setup(:default, :test)

if ENV["SIMPLECOV"]
  require "simplecov"
  require "simplecov-rcov"
  require "simplecov-clover"

  SimpleCov.formatter = Class.new do
    def format(result)
      SimpleCov::Formatter::CloverFormatter.new.format(result)
      SimpleCov::Formatter::RcovFormatter.new.format(result)
    end
  end

  SimpleCov.root(File.expand_path("../..", __FILE__))
  SimpleCov.add_filter("spec")
  SimpleCov.add_filter("vendor")
  SimpleCov.coverage_dir(ENV["SIMPLECOV_DIR"] || "spec_coverage")
  SimpleCov.start
end

require "rack/test"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

ENV["RACK_ENV"] = "test"

require "simple_blobstore_server"

Rspec.configure do |rspec_config|
  rspec_config.before(:each) do
  end

  rspec_config.after(:each) do
  end

  rspec_config.after(:all) do
  end
end
