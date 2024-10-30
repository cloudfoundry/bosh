require 'simplecov'

SimpleCov.configure do
  add_filter '/spec/'
  add_filter '/vendor/'
end

SimpleCov.start do
  root          BOSH_REPO_SRC_DIR
  merge_timeout 3600
  # command name is injected by the spec.rake runner
  command_name ENV['BOSH_BUILD_NAME'] if ENV['BOSH_BUILD_NAME']
end
