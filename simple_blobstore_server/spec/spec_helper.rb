$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["RACK_ENV"] = "test"

require "simple_blobstore_server"

Bundler.require(:test)

Spec::Runner.configure do |rspec_config|
  rspec_config.before(:each) do
  end

  rspec_config.after(:each) do
  end

  rspec_config.after(:all) do
  end
end
