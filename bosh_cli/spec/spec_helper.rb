require File.expand_path('../../../spec/shared/spec_helper', __FILE__)

require 'cli'
require 'fakefs/spec_helpers'
require 'timecop'
require 'webmock'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

def spec_asset(dir_or_file_name)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', dir_or_file_name))
end

RSpec.configure do |c|
  c.before do
    Bosh::Cli::Config.interactive = false
    Bosh::Cli::Config.colorize = false
    Bosh::Cli::Config.output = StringIO.new
  end

  c.include WebMock::API

  c.color = true
end
