ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
Bundler.setup(:default, :test)

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
