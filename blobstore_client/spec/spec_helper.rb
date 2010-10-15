$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)
require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "blobstore_client"

Rspec.configure do |rspec_config|
  rspec_config.before(:each) do
  end

  rspec_config.after(:each) do
  end

  rspec_config.after(:all) do
  end
end
