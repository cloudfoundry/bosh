ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "blobstore_client"

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end